package com.wanx.wanx.vpn

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Native side of lib/core/platform/vpn_channel.dart. */
class VpnChannel : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val METHOD_CHANNEL = "com.wanx/vpn"
        private const val EVENT_CHANNEL = "com.wanx/vpn/status"
        private const val TRAFFIC_CHANNEL = "com.wanx/vpn/traffic"
        private const val REQUEST_VPN_PERMISSION = 0x4e58
        private const val REQUEST_NOTIFICATION_PERMISSION = 0x4e59
    }

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var traffic: EventChannel
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPrepare: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null
    private var statusListener: ((Map<String, Any?>) -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
        traffic = EventChannel(binding.binaryMessenger, TRAFFIC_CHANNEL).also {
            it.setStreamHandler(TrafficMonitor(binding.applicationContext))
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        traffic.setStreamHandler(null)
        onCancel(null)
        this.binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = binding?.applicationContext ?: return result.error("NO_CONTEXT", null, null)
        when (call.method) {
            "prepare" -> prepare(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "start" -> {
                val config = call.argument<String>("config")
                    ?: return result.error("BAD_ARGS", "config is required", null)
                NovaVpnService.start(
                    context, config, call.argument<String>("name") ?: "WanX",
                    call.argument<String>("disconnectLabel") ?: "Disconnect",
                    checkWindowMs = call.argument<Number>("checkWindowMs")?.toLong() ?: 0,
                    deadlineMessage = call.argument<String>("deadlineMessage"),
                )
                result.success(null)
            }
            "clearDeadline" -> {
                NovaVpnService.clearDeadline(context)
                result.success(null)
            }
            "stop" -> {
                NovaVpnService.stop(context)
                result.success(null)
            }
            "status" -> result.success(VpnState.snapshot())
            "version" -> result.success(BoxCore.version())
            "deviceInfo" -> result.success(
                mapOf(
                    // Stable per device and signing key; survives reinstalls.
                    // 16 lowercase hex characters, like Happ.
                    "hwid" to (Settings.Secure.getString(
                        context.contentResolver, Settings.Secure.ANDROID_ID,
                    ) ?: "").lowercase().padStart(16, '0').takeLast(16),
                    "os" to "Android",
                    "osVersion" to Build.VERSION.RELEASE,
                    "model" to Build.MODEL,
                ),
            )
            "installedApps" -> InstalledApps.list(context) { apps -> result.success(apps) }
            "testLatency" -> {
                val outbound = call.argument<String>("outbound")
                    ?: return result.error("BAD_ARGS", "outbound is required", null)
                LatencyProbe.test(
                    context,
                    outbound,
                    dnsServer = call.argument<String>("dnsServer") ?: LatencyProbe.DEFAULT_DNS,
                    url = call.argument<String>("url") ?: LatencyProbe.DEFAULT_URL,
                    timeoutMs = call.argument<Int>("timeoutMs") ?: 5000,
                ) { outcome ->
                    when (outcome) {
                        is LatencyProbe.Outcome.Delay -> result.success(outcome.ms)
                        is LatencyProbe.Outcome.Failed -> result.success(null)
                        is LatencyProbe.Outcome.Unsupported ->
                            result.error("UNSUPPORTED", outcome.reason, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Shows the system VPN consent dialog if the app is not yet authorized. */
    private fun prepare(result: MethodChannel.Result) {
        val activity: Activity = activityBinding?.activity
            ?: return result.error("NO_ACTIVITY", "VPN consent needs a foreground activity", null)
        val intent = VpnService.prepare(activity) ?: return result.success(true)
        if (pendingPrepare != null) return result.error("BUSY", "Consent dialog already shown", null)
        pendingPrepare = result
        activity.startActivityForResult(intent, REQUEST_VPN_PERMISSION)
    }

    /**
     * Android 13+ needs POST_NOTIFICATIONS at runtime, otherwise the VPN
     * foreground notification (with the Disconnect action) is hidden.
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return result.success(true)
        val activity: Activity = activityBinding?.activity
            ?: return result.error("NO_ACTIVITY", "Permission request needs a foreground activity", null)
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED) {
            return result.success(true)
        }
        if (pendingNotifications != null) return result.error("BUSY", "Permission dialog already shown", null)
        pendingNotifications = result
        ActivityCompat.requestPermissions(activity, arrayOf(permission), REQUEST_NOTIFICATION_PERMISSION)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return false
        pendingNotifications?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingNotifications = null
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_VPN_PERMISSION) return false
        pendingPrepare?.success(resultCode == Activity.RESULT_OK)
        pendingPrepare = null
        return true
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val listener: (Map<String, Any?>) -> Unit = { sink.success(it) }
        statusListener = listener
        VpnState.addListener(listener)
        sink.success(VpnState.snapshot())
    }

    override fun onCancel(arguments: Any?) {
        statusListener?.let(VpnState::removeListener)
        statusListener = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        pendingPrepare?.success(false)
        pendingPrepare = null
        pendingNotifications?.success(false)
        pendingNotifications = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
}
