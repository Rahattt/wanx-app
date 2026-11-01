package com.wanx.wanx.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.wanx.wanx.MainActivity
import com.wanx.wanx.R
import java.util.Locale
import java.util.concurrent.Executors

class NovaVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.wanx.wanx.vpn.START"
        const val ACTION_STOP = "com.wanx.wanx.vpn.STOP"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_NAME = "name"
        const val EXTRA_DISCONNECT_LABEL = "disconnectLabel"
        const val ACTION_CLEAR_DEADLINE = "com.wanx.wanx.vpn.CLEAR_DEADLINE"
        const val EXTRA_CHECK_WINDOW = "checkWindowMs"
        const val EXTRA_DEADLINE_MESSAGE = "deadlineMessage"
        private const val DEADLINE_NOTIFICATION_ID = 2

        private const val NOTIFICATION_CHANNEL = "vpn"
        private const val NOTIFICATION_ID = 1

        /**
         * [checkWindowMs] (0 = none): a premium link not yet checked may only
         * run that long once the tunnel is up, unless [clearDeadline] comes
         * first — enforced here, so closing the app doesn't keep it up.
         */
        fun start(
            context: Context,
            config: String,
            name: String,
            disconnectLabel: String,
            checkWindowMs: Long = 0,
            deadlineMessage: String? = null,
        ) {
            val intent = Intent(context, NovaVpnService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_CONFIG, config)
                .putExtra(EXTRA_NAME, name)
                .putExtra(EXTRA_DISCONNECT_LABEL, disconnectLabel)
                .putExtra(EXTRA_CHECK_WINDOW, checkWindowMs)
                .putExtra(EXTRA_DEADLINE_MESSAGE, deadlineMessage)
            context.startForegroundService(intent)
        }

        /** The premium check passed: keep running. */
        fun clearDeadline(context: Context) {
            context.startService(
                Intent(context, NovaVpnService::class.java).setAction(ACTION_CLEAR_DEADLINE)
            )
        }

        /** The running service, so [LatencyProbe] can protect its sockets. */
        @Volatile
        var active: NovaVpnService? = null
            private set

        fun stop(context: Context) {
            context.startService(Intent(context, NovaVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    private val core: BoxCore by lazy { BoxCore.create(this) { stopTunnel() } }
    // The core blocks while starting; keep it off the main thread and serialized.
    private val worker = Executors.newSingleThreadExecutor()
    // Guarded by itself: null once the tunnel stops, so a late traffic
    // update can't bring the notification back.
    private val notificationLock = Any()
    private var notification: NotificationCompat.Builder? = null
    // Live speed in the notification while connected.
    private val traffic by lazy {
        TrafficClient(this) { message ->
            synchronized(notificationLock) {
                val builder = notification ?: return@TrafficClient
                builder.setContentText(
                    "↑ ${formatSpeed(message.uplink)}   ↓ ${formatSpeed(message.downlink)}"
                )
                builder.setSubText(formatBytes(message.uplinkTotal + message.downlinkTotal))
                getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, builder.build())
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private var deadlineMessage: String? = null
    // Set at each start; cleared (on the main thread) once the check passed.
    private var checkWindowMs = 0L
    private val deadlineReached = Runnable { stopTunnel(deadlineMessage) }

    override fun onCreate() {
        super.onCreate()
        active = this
    }

    /** Latest start; a stop only ends the service if nothing came after it. */
    @Volatile
    private var lastStartId = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastStartId = startId
        when (intent?.action) {
            ACTION_STOP -> stopTunnel()
            ACTION_CLEAR_DEADLINE -> {
                checkWindowMs = 0
                main.removeCallbacks(deadlineReached)
            }
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG)
                if (config == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                main.removeCallbacks(deadlineReached)
                checkWindowMs = intent.getLongExtra(EXTRA_CHECK_WINDOW, 0)
                deadlineMessage = intent.getStringExtra(EXTRA_DEADLINE_MESSAGE)
                startTunnel(
                    config,
                    intent.getStringExtra(EXTRA_NAME) ?: "WanX",
                    intent.getStringExtra(EXTRA_DISCONNECT_LABEL) ?: "Disconnect",
                )
            }
        }
        return START_NOT_STICKY
    }

    private fun startTunnel(config: String, name: String, disconnectLabel: String) {
        val startId = lastStartId
        VpnState.update(VpnStatus.CONNECTING)
        startInForeground(name, disconnectLabel)
        worker.execute {
            try {
                core.start(this, config)
                VpnState.update(VpnStatus.CONNECTED)
                traffic.start()
                // The check window runs from here, once the tunnel is up.
                main.post {
                    if (checkWindowMs > 0) main.postDelayed(deadlineReached, checkWindowMs)
                }
            } catch (e: Exception) {
                core.stop()
                VpnState.update(VpnStatus.ERROR, e.message ?: e.javaClass.simpleName)
                stopForegroundAndSelf(startId)
            }
        }
    }

    /** [reason], if given, is shown in the app and as a notification. */
    private fun stopTunnel(reason: String? = null) {
        val startId = lastStartId
        main.removeCallbacks(deadlineReached)
        VpnState.update(VpnStatus.DISCONNECTING)
        traffic.stop()
        worker.execute {
            core.stop()
            VpnState.update(VpnStatus.DISCONNECTED, reason)
            if (reason != null) notifyStopped(reason)
            stopForegroundAndSelf(startId)
        }
    }

    private fun notifyStopped(reason: String) {
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        getSystemService(NotificationManager::class.java).notify(
            DEADLINE_NOTIFICATION_ID,
            NotificationCompat.Builder(this, NOTIFICATION_CHANNEL)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("WanX")
                .setContentText(reason)
                .setStyle(NotificationCompat.BigTextStyle().bigText(reason))
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build(),
        )
    }

    /** Called by the system when the user revokes VPN permission or another VPN takes over. */
    override fun onRevoke() = stopTunnel()

    override fun onDestroy() {
        main.removeCallbacks(deadlineReached)
        active = null
        traffic.stop()
        worker.execute { core.stop() }
        worker.shutdown()
        if (VpnState.status != VpnStatus.ERROR) VpnState.update(VpnStatus.DISCONNECTED)
        super.onDestroy()
    }

    /**
     * Ends the service for [startId] only: a reconnect right after a stop
     * started again meanwhile, and must keep its service (and deadline).
     */
    private fun stopForegroundAndSelf(startId: Int) {
        if (startId != lastStartId) return
        synchronized(notificationLock) { notification = null }
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
    }

    private fun startInForeground(serverName: String, disconnectLabel: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(NOTIFICATION_CHANNEL, "VPN status", NotificationManager.IMPORTANCE_LOW)
        )
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, NovaVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(serverName)
            .setContentText("WanX")
            .setContentIntent(openApp)
            .addAction(0, disconnectLabel, stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSilent(true)
        synchronized(notificationLock) { notification = builder }
        val notification: Notification = builder.build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }
}

/** Mirrors the app's formatBytes: 1536 → "1.5 KB"; one decimal below 10. */
internal fun formatBytes(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val units = arrayOf("KB", "MB", "GB", "TB")
    var value = bytes / 1024.0
    var unit = 0
    while (value >= 1024 && unit < units.lastIndex) {
        value /= 1024
        unit++
    }
    val text = String.format(Locale.US, if (value < 10) "%.1f" else "%.0f", value)
    return "$text ${units[unit]}"
}

internal fun formatSpeed(bytesPerSecond: Long) = "${formatBytes(bytesPerSecond)}/s"
