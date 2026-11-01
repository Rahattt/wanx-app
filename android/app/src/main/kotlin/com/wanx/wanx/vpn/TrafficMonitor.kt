package com.wanx.wanx.vpn

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.ConnectionEvents
import io.nekohasekai.libbox.DnsQuery
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LogIterator
import io.nekohasekai.libbox.OutboundGroupItemIterator
import io.nekohasekai.libbox.OutboundGroupIterator
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Streams live traffic of the running tunnel to Flutter as
 * {uplink, downlink (bytes/s), uplinkTotal, downlinkTotal}, once a second.
 */
class TrafficMonitor(context: Context) : EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    @Volatile private var sink: EventChannel.EventSink? = null
    private val client = TrafficClient(context) { message ->
        val event = mapOf(
            "uplink" to message.uplink,
            "downlink" to message.downlink,
            "uplinkTotal" to message.uplinkTotal,
            "downlinkTotal" to message.downlinkTotal,
        )
        main.post { sink?.success(event) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        client.start()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        client.stop()
    }
}

/**
 * Reads traffic stats once a second from the libbox command server started
 * by [LibboxCore]. Keeps retrying while started, since the tunnel may still
 * be starting. [onStatus] runs on a background thread.
 */
class TrafficClient(
    private val context: Context,
    private val onStatus: (StatusMessage) -> Unit,
) : CommandClientHandler {

    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var client: CommandClient? = null
    @Volatile private var listening = false

    fun start() {
        executor.execute {
            listening = true
            connect()
        }
    }

    fun stop() {
        listening = false
        executor.execute {
            runCatching { client?.disconnect() }
            client = null
        }
    }

    /** Runs on [executor]. */
    private fun connect() {
        if (!listening || client != null) return
        try {
            LibboxCore.setup(context)
            val options = CommandClientOptions().apply {
                addCommand(Libbox.CommandStatus)
                statusInterval = TimeUnit.SECONDS.toNanos(1)
            }
            val client = Libbox.newCommandClient(this, options)
            this.client = client
            client.connect()
        } catch (e: Exception) {
            client = null
            retry()
        }
    }

    private fun retry() {
        executor.schedule({ connect() }, 2, TimeUnit.SECONDS)
    }

    override fun connected() {}

    override fun disconnected(message: String?) {
        executor.execute {
            client = null
            retry()
        }
    }

    override fun writeStatus(message: StatusMessage?) {
        if (message == null || !message.trafficAvailable || !listening) return
        onStatus(message)
    }

    override fun clearLogs() {}
    override fun initializeClashMode(modeList: StringIterator?, currentMode: String?) {}
    override fun setDefaultLogLevel(level: Int) {}
    override fun updateClashMode(newMode: String?) {}
    override fun writeConnectionEvents(events: ConnectionEvents?) {}
    override fun writeDNSQuery(query: DnsQuery?) {}
    override fun writeGroups(message: OutboundGroupIterator?) {}
    override fun writeLogs(messageList: LogIterator?) {}
    override fun writeOutbounds(message: OutboundGroupItemIterator?) {}
}
