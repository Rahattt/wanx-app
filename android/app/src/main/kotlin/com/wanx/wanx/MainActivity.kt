package com.wanx.wanx

import android.content.Intent
import com.wanx.wanx.sealed.SealedKeys
import com.wanx.wanx.vpn.VpnChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** Native side of lib/core/platform/link_channel.dart. */
    private var links: MethodChannel? = null

    /** A wanx:// link the app was opened with, until Dart takes it. */
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(VpnChannel())
        flutterEngine.plugins.add(SealedKeys())
        pending = linkOf(intent)
        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.wanx/link").also {
            it.setMethodCallHandler { call, result ->
                if (call.method != "take") return@setMethodCallHandler result.notImplemented()
                result.success(pending)
                pending = null
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = linkOf(intent) ?: return
        links?.invokeMethod("link", link) ?: run { pending = link }
    }

    private fun linkOf(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme.equals("wanx", ignoreCase = true) }?.toString()
}
