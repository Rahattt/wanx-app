package com.wanx.wanx.vpn

import android.os.Handler
import android.os.Looper

/** Wire values must match `VpnStatus` in lib/features/vpn/domain/vpn_status.dart. */
enum class VpnStatus(val wire: String) {
    DISCONNECTED("disconnected"),
    CONNECTING("connecting"),
    CONNECTED("connected"),
    DISCONNECTING("disconnecting"),
    ERROR("error"),
}

/**
 * Process-wide tunnel state. The service writes it, the Flutter channel
 * observes it. Listeners are always invoked on the main thread.
 */
object VpnState {
    @Volatile var status: VpnStatus = VpnStatus.DISCONNECTED
        private set
    @Volatile var error: String? = null
        private set

    private val listeners = mutableSetOf<(Map<String, Any?>) -> Unit>()
    private val main = Handler(Looper.getMainLooper())

    fun snapshot(): Map<String, Any?> = mapOf("status" to status.wire, "error" to error)

    fun update(status: VpnStatus, error: String? = null) {
        this.status = status
        this.error = error
        main.post {
            val event = snapshot()
            synchronized(listeners) { listeners.toList() }.forEach { it(event) }
        }
    }

    fun addListener(listener: (Map<String, Any?>) -> Unit) {
        synchronized(listeners) { listeners += listener }
    }

    fun removeListener(listener: (Map<String, Any?>) -> Unit) {
        synchronized(listeners) { listeners -= listener }
    }
}
