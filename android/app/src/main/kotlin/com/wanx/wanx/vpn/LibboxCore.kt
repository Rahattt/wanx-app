package com.wanx.wanx.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.RoutePrefixIterator
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface as JavaNetworkInterface
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.NetworkInterface as BoxNetworkInterface

/**
 * sing-box core backed by libbox.aar. The core runs inside a libbox
 * CommandServer; this class is its PlatformInterface on Android.
 */
class LibboxCore(
    private val context: Context,
    /** Invoked when the core asks to stop itself (e.g. fatal runtime error). */
    private val onStopRequested: () -> Unit,
) : BoxCore, PlatformInterface, CommandServerHandler {

    companion object {
        private const val TAG = "LibboxCore"
        @Volatile private var setupDone = false

        /** Process-wide libbox init; also used by [LatencyProbe]. */
        @Synchronized
        internal fun setup(context: Context) {
            if (setupDone) return
            val app = context.applicationContext
            Libbox.setup(SetupOptions().apply {
                basePath = app.filesDir.absolutePath
                workingPath = (app.getExternalFilesDir(null) ?: app.filesDir).absolutePath
                tempPath = app.cacheDir.absolutePath
                // Mirrors sing-box-for-android: gVisor stack workaround for these API levels.
                fixAndroidStack = Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1 ||
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                logMaxLines = 3000
            })
            setupDone = true
        }
    }

    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private var service: VpnService? = null
    private var server: CommandServer? = null
    private var tunFd: ParcelFileDescriptor? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override val version: String get() = Libbox.version()

    override fun start(service: VpnService, configJson: String) {
        setup(context)
        this.service = service
        val server = Libbox.newCommandServer(this, this)
        this.server = server
        // gRPC on command.sock in filesDir: TrafficMonitor reads live stats.
        server.start()
        server.startOrReloadService(configJson, OverrideOptions())
    }

    override fun stop() {
        server?.let {
            runCatching { it.closeService() }.onFailure { e -> Log.w(TAG, "closeService", e) }
            it.close()
        }
        server = null
        closeTun()
        service = null
    }

    private fun closeTun() {
        runCatching { tunFd?.close() }
        tunFd = null
    }

    // region PlatformInterface: tunnel

    override fun openTun(options: TunOptions): Int {
        val service = service ?: error("VPN service is not running")
        if (!options.autoRoute) error("TUN inbound must set auto_route on Android")
        val builder = service.Builder()
            .setSession("WanX")
            .setMtu(options.mtu)
            .setBlocking(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)

        val inet4 = options.inet4Address.toList()
        val inet6 = options.inet6Address.toList()
        inet4.forEach { builder.addAddress(it.address(), it.prefix()) }
        inet6.forEach { builder.addAddress(it.address(), it.prefix()) }

        val dns = options.dnsServerAddress
        while (dns.hasNext()) builder.addDnsServer(dns.next())

        val routes4 = options.inet4RouteRange.toList()
        val routes6 = options.inet6RouteRange.toList()
        if (inet4.isNotEmpty()) {
            if (routes4.isEmpty()) builder.addRoute("0.0.0.0", 0)
            routes4.forEach { builder.addRoute(it.address(), it.prefix()) }
        }
        if (inet6.isNotEmpty()) {
            if (routes6.isEmpty()) builder.addRoute("::", 0)
            routes6.forEach { builder.addRoute(it.address(), it.prefix()) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            (options.inet4RouteExcludeAddress.toList() + options.inet6RouteExcludeAddress.toList())
                .forEach { builder.excludeRoute(IpPrefix(InetAddress.getByName(it.address()), it.prefix())) }
        }

        val include = options.includePackage.toList()
        val exclude = options.excludePackage.toList()
        include.forEach { runCatching { builder.addAllowedApplication(it) } }
        if (include.isEmpty()) exclude.forEach { runCatching { builder.addDisallowedApplication(it) } }

        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.httpProxyServer,
                    options.httpProxyServerPort,
                    options.httpProxyBypassDomain.toList(),
                )
            )
        }

        closeTun()
        val pfd = builder.establish() ?: error("VPN permission revoked or another VPN is active")
        tunFd = pfd
        return pfd.fd
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    /** Excludes the core's own outbound sockets from the tunnel. */
    override fun autoDetectInterfaceControl(fd: Int) {
        if (service?.protect(fd) != true) error("failed to protect socket $fd")
    }

    // endregion

    // region PlatformInterface: network state

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = report(network)
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = report(network)
            override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) = report(network)
            override fun onLost(network: Network) {
                if (connectivity.activeNetwork == null) listener.updateDefaultInterface("", -1, false, false)
            }

            private fun report(network: Network) {
                val name = connectivity.getLinkProperties(network)?.interfaceName ?: return
                val caps = connectivity.getNetworkCapabilities(network)
                val index = runCatching { JavaNetworkInterface.getByName(name)?.index }.getOrNull() ?: -1
                val expensive = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false
                listener.updateDefaultInterface(name, index, expensive, false)
            }
        }
        val handler = Handler(Looper.getMainLooper())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Best matching non-VPN internet network = what the core should bind to.
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .build()
            connectivity.registerBestMatchingNetworkCallback(request, callback, handler)
        } else {
            connectivity.registerDefaultNetworkCallback(callback, handler)
        }
        networkCallback = callback
        connectivity.activeNetwork?.let { callback.onAvailable(it) }
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        networkCallback?.let { runCatching { connectivity.unregisterNetworkCallback(it) } }
        networkCallback = null
    }

    @Suppress("DEPRECATION")
    override fun getInterfaces(): NetworkInterfaceIterator {
        val result = mutableListOf<BoxNetworkInterface>()
        for (network in connectivity.allNetworks) {
            val lp = connectivity.getLinkProperties(network) ?: continue
            val caps = connectivity.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            val name = lp.interfaceName ?: continue
            val javaIf = runCatching { JavaNetworkInterface.getByName(name) }.getOrNull() ?: continue
            result += BoxNetworkInterface().apply {
                this.name = name
                index = javaIf.index
                mtu = javaIf.mtu
                addresses = StringArrayIterator(
                    lp.linkAddresses.map { "${it.address.hostAddress?.substringBefore('%')}/${it.prefixLength}" }
                )
                flags = interfaceFlags(javaIf)
                type = when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                dnsServer = StringArrayIterator(lp.dnsServers.mapNotNull { it.hostAddress })
                metered = !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            }
        }
        return InterfaceArrayIterator(result)
    }

    /** net.Flags bit layout from Go: up, broadcast, loopback, pointtopoint, multicast. */
    private fun interfaceFlags(i: JavaNetworkInterface): Int {
        var flags = 0
        if (i.isUp) flags = flags or 1
        if (i.interfaceAddresses.any { it.broadcast != null }) flags = flags or 2
        if (i.isLoopback) flags = flags or 4
        if (i.isPointToPoint) flags = flags or 8
        if (i.supportsMulticast()) flags = flags or 16
        return flags
    }

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) error("unsupported below Android 10")
        val uid = connectivity.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )
        if (uid == Process.INVALID_UID) error("connection owner not found")
        val packages = context.packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        return ConnectionOwner().apply {
            userId = uid
            userName = packages.firstOrNull().orEmpty()
            setAndroidPackageNames(StringArrayIterator(packages))
        }
    }

    override fun localDNSTransport(): LocalDNSTransport? = null
    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    // Reading SSID needs location permission; not used by WanX routing rules.
    override fun readWIFIState(): WIFIState? = null
    override fun clearDNSCache() = Unit
    override fun registerMyInterface(name: String) = Unit
    override fun startNeighborMonitor(listener: NeighborUpdateListener) = Unit
    override fun closeNeighborMonitor(listener: NeighborUpdateListener) = Unit

    // endregion

    // region PlatformInterface: features WanX does not use

    override fun sendNotification(notification: Notification) = Unit
    override fun cancelNotification(identifier: String, typeID: Int) = Unit
    override fun usePlatformShell(): Boolean = false
    override fun checkPlatformShell() = error("platform shell is not supported")
    override fun openShellSession(
        user: PlatformUser, command: String, environ: StringIterator, term: String, rows: Int, cols: Int,
    ): ShellSession = error("platform shell is not supported")
    override fun lookupUser(username: String): PlatformUser = error("not supported")
    override fun lookupSFTPServer(): String = error("not supported")
    override fun readSystemSSHHostKey(): String = error("not supported")
    override fun tailscaleHostname(): String = Build.MODEL
    override fun usePlatformBridge(): Boolean = false
    override fun createBridge(options: BridgeOptions): BridgeSession = error("bridge is not supported")

    // endregion

    // region CommandServerHandler

    override fun serviceStop() {
        Handler(Looper.getMainLooper()).post(onStopRequested)
    }

    override fun serviceReload() = error("reload is not supported; reconnect instead")
    override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus()
    override fun setSystemProxyEnabled(enabled: Boolean) = Unit
    override fun triggerNativeCrash() = error("not supported")
    override fun writeDebugMessage(message: String) {
        Log.d(TAG, message)
    }
    override fun connectSSHAgent(): Int = error("not supported")

    // endregion
}

private fun RoutePrefixIterator.toList() = buildList { while (hasNext()) add(next()) }

private fun StringIterator.toList() = buildList { while (hasNext()) add(next()) }

private class StringArrayIterator(private val values: List<String>) : StringIterator {
    private var i = 0
    override fun len(): Int = values.size
    override fun hasNext(): Boolean = i < values.size
    override fun next(): String = values[i++]
}

private class InterfaceArrayIterator(private val values: List<BoxNetworkInterface>) : NetworkInterfaceIterator {
    private var i = 0
    override fun hasNext(): Boolean = i < values.size
    override fun next(): BoxNetworkInterface = values[i++]
}
