package com.wanx.wanx.vpn

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.random.Random

/**
 * Measures a server's delay through its real sing-box outbound, independent
 * of the active tunnel: each test starts a throwaway core with only that
 * outbound plus the Clash API, calls `/proxies/test/delay` (sing-box's
 * urltest, the same code urltest groups use) and shuts the core down.
 */
object LatencyProbe {
    const val DEFAULT_URL = "https://www.gstatic.com/generate_204"
    const val DEFAULT_DNS = "1.1.1.1"
    private const val TAG = "LatencyProbe"
    private const val OUTBOUND_TAG = "test"

    sealed interface Outcome {
        data class Delay(val ms: Int) : Outcome
        /** Tested but unreachable, timed out or rejected by the server. */
        data object Failed : Outcome
        /** The core refused the config (e.g. protocol not built into libbox). */
        data class Unsupported(val reason: String) : Outcome
    }

    // Tests are independent; cap how many throwaway cores run at once.
    private val executor = Executors.newFixedThreadPool(4)
    // Port pick + core start must not interleave, or two cores race for a port.
    private val startLock = Any()
    private val main = Handler(Looper.getMainLooper())

    fun test(
        context: Context,
        outboundJson: String,
        dnsServer: String,
        url: String,
        timeoutMs: Int,
        onResult: (Outcome) -> Unit,
    ) {
        val app = context.applicationContext
        executor.execute {
            val outcome = runCatching { run(app, outboundJson, dnsServer, url, timeoutMs) }
                .getOrElse { Outcome.Unsupported(it.message ?: it.javaClass.simpleName) }
            main.post { onResult(outcome) }
        }
    }

    private fun run(context: Context, outboundJson: String, dns: String, url: String, timeoutMs: Int): Outcome {
        LibboxCore.setup(context)
        val secret = UUID.randomUUID().toString()
        // libbox always opens a cache file; the default cache.db is locked by
        // the tunnel core in this same process, so each probe gets its own.
        val cacheFile = java.io.File(context.cacheDir, "probe-$secret.db")
        var server: CommandServer? = null
        try {
            val port: Int
            synchronized(startLock) {
                port = Libbox.availablePort(Random.nextInt(20000, 40000))
                val config = config(JSONObject(outboundJson), dns, port, secret, cacheFile.absolutePath)
                val created = Libbox.newCommandServer(NoopHandler, ProbePlatform(LibboxCore(context) {}))
                server = created
                try {
                    created.startOrReloadService(config, OverrideOptions())
                } catch (e: Exception) {
                    return Outcome.Unsupported(e.message ?: "core rejected the outbound")
                }
            }
            val client = Libbox.newHTTPClient()
            return try {
                val request = client.newRequest()
                request.setURL(
                    "http://127.0.0.1:$port/proxies/$OUTBOUND_TAG/delay" +
                        "?url=${URLEncoder.encode(url, "UTF-8")}&timeout=$timeoutMs"
                )
                request.setHeader("Authorization", "Bearer $secret")
                val body = request.execute().content.value
                val delay = JSONObject(body).optInt("delay")
                if (delay > 0) Outcome.Delay(delay) else Outcome.Failed
            } catch (e: Exception) {
                // Non-200 from the Clash API: 503 (test failed) or 504 (timeout).
                Log.d(TAG, "delay test failed: ${e.message}")
                Outcome.Failed
            } finally {
                client.close()
            }
        } finally {
            server?.let {
                runCatching { it.closeService() }
                it.close()
            }
            cacheFile.delete()
        }
    }

    private fun config(outbound: JSONObject, dns: String, port: Int, secret: String, cacheFile: String): String =
        JSONObject()
            .put("log", JSONObject().put("level", "warn"))
            .put("dns", JSONObject().put("servers", JSONArray().put(
                JSONObject().put("tag", "local").put("type", "udp").put("server", dns)
            )))
            .put("outbounds", JSONArray()
                .put(outbound.put("tag", OUTBOUND_TAG))
                .put(JSONObject().put("type", "direct").put("tag", "direct")))
            .put("route", JSONObject()
                .put("final", OUTBOUND_TAG)
                .put("auto_detect_interface", true)
                .put("default_domain_resolver", "local"))
            .put("experimental", JSONObject()
                .put("clash_api", JSONObject()
                    .put("external_controller", "127.0.0.1:$port")
                    .put("secret", secret))
                .put("cache_file", JSONObject().put("path", cacheFile)))
            .toString()

    /**
     * Reuses LibboxCore's network monitoring (physical, non-VPN network), but
     * protects sockets via whichever VPN service is running, if any, so the
     * probe never loops through the active tunnel. It has no TUN.
     */
    private class ProbePlatform(delegate: LibboxCore) : PlatformInterface by delegate {
        override fun autoDetectInterfaceControl(fd: Int) {
            NovaVpnService.active?.protect(fd)
        }

        override fun openTun(options: TunOptions): Int = error("latency probe has no TUN")
    }

    private object NoopHandler : CommandServerHandler {
        override fun serviceStop() = Unit
        override fun serviceReload() = Unit
        override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()
        override fun setSystemProxyEnabled(enabled: Boolean) = Unit
        override fun triggerNativeCrash() = Unit
        override fun writeDebugMessage(message: String) = Unit
        override fun connectSSHAgent(): Int = error("not supported")
    }
}
