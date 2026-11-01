package com.wanx.wanx.vpn

import android.content.Context
import android.net.VpnService
import io.nekohasekai.libbox.Libbox

/**
 * Seam between the VpnService and the sing-box core (libbox.aar built with
 * gomobile, see scripts/build_libbox.sh). The implementation is [LibboxCore].
 */
interface BoxCore {
    val version: String

    /** Starts sing-box with [configJson]. Throws on invalid config or core failure. Blocking. */
    fun start(service: VpnService, configJson: String)

    fun stop()

    companion object {
        fun create(context: Context, onStopRequested: () -> Unit): BoxCore =
            LibboxCore(context, onStopRequested)

        /** Core version without starting anything. */
        fun version(): String = Libbox.version()
    }
}
