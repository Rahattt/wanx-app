# WanX

VPN client for iOS and Android. It uses [sing-box](https://github.com/SagerNet/sing-box)
(GPLv3) as its core, built from the [sing-box-lx](https://github.com/Leadaxe/sing-box-lx)
fork (XHTTP, AmneziaWG); WanX is not affiliated with either project.

## Architecture

```
┌──────────────────────── Flutter (Dart) ────────────────────────┐
│ ServersScreen ─► ServersController ─► ServerRepository (prefs) │
│       │            ShareLinkParser (vless/vmess/trojan/ss/…)    │
│       ▼                                                        │
│ VpnController ─► SingBoxConfigBuilder ─► VpnChannel            │
└──────────────────────────────┬─────────────────────────────────┘
          MethodChannel "com.wanx/vpn"  │  EventChannel "com.wanx/vpn/status"
               ┌─────────────────────────┴───────────────────────┐
     Android   ▼                                          iOS    ▼
  VpnChannel.kt (plugin)                         VpnChannel.swift (plugin)
  NovaVpnService : VpnService                    NETunnelProviderManager
        │                                                │  (separate process)
        ▼                                                ▼
  BoxCore ─► libbox.aar (gomobile)          PacketTunnelProvider ─► BoxCore
                                             ─► Libbox.xcframework (gomobile)
```

Dart builds the full sing-box JSON config (TUN inbound + selected outbound)
and hands it to the native side. The native side only owns the tunnel
lifecycle and the core; it knows nothing about share links or UI state.

### Channel contract

| Method    | Args                              | Result                       |
|-----------|-----------------------------------|------------------------------|
| `prepare` | —                                 | `bool` (VPN consent granted) |
| `start`   | `{config: String, name: String}`  | —                            |
| `stop`    | —                                 | —                            |
| `status`  | —                                 | `{status, error}`            |
| `version` | —                                 | `String?` (core version)     |

Status values: `disconnected | connecting | connected | disconnecting | error`.

### Layout

```
lib/
  core/platform/vpn_channel.dart         platform channel wrapper
  core/singbox/config_builder.dart       sing-box config generation
  features/servers/{domain,data,application,presentation}
  features/vpn/{domain,application}
android/app/src/main/kotlin/com/wanx/wanx/vpn/
  VpnChannel.kt  NovaVpnService.kt  VpnStatus.kt  BoxCore.kt
ios/Runner/VpnChannel.swift
ios/PacketTunnel/                        Network Extension sources
scripts/build_libbox.sh                  builds libbox via gomobile
```

## Linking the sing-box core

```sh
scripts/build_libbox.sh android   # → android/app/libs/libbox.aar
scripts/build_libbox.sh apple     # → ios/Frameworks/Libbox.xcframework
```

The core is built from a pinned sing-box-lx release: the script checks the
tag and the four dependency submodules it swaps in (utls, gvisor, sing-tun,
wireguard-go) and fetches only those. To update, change `LX_VERSION`,
`LX_COMMIT` and `SUBMODULES` together.

Requires Go, Xcode (apple) and the Android NDK (android):
`ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<version>`. The libbox-backed
cores are `LibboxCore.kt` and `ios/PacketTunnel/LibboxCore.swift`; both run
sing-box inside a libbox `CommandServer` and implement its `PlatformInterface`.
The build artifacts are git-ignored, so run the script after every fresh clone.

Both platforms get a slim libbox with only the features WanX uses (see
`SLIM_TAGS`). On iOS the script also relinks gomobile's static library into a dynamic
`Libbox.framework`. Runner embeds it once and the PacketTunnel extension loads
it from the app bundle, so the core is not duplicated. To use a sing-box
feature that was left out (e.g. Tailscale), add its tag to `SLIM_TAGS`.

## Build-time keys

Opening encrypted `wanx://` links needs the link private key, which is not in
the source. Copy `keys.example.json` to `keys.json` (git-ignored), fill it in
and pass it to every build and test run:

```sh
flutter build apk --release --dart-define-from-file=keys.json
flutter test --dart-define-from-file=keys.json
```

Without it the app builds and works, but `wanx://` links don't open.

## iOS: signing

The `PacketTunnel` app extension target is already in `Runner.xcodeproj`
(sources in `ios/PacketTunnel/`, links the shared Libbox.framework, embedded
into Runner). Both targets use automatic signing with the Runner team and carry
the **Network Extensions** (Packet Tunnel) and **App Groups**
(`group.com.wanx.wanx`) entitlements. On the first device build, open
`ios/Runner.xcworkspace` → each target → Signing & Capabilities so Xcode
registers the App Group and both App IDs in your developer account.

Network Extensions don't run in the iOS Simulator — test on a device.
A paid Apple Developer account is required for the Network Extension entitlement.

## License

WanX is free software under the GNU General Public License v3.0 or later
(see `LICENSE`), because it links the GPLv3 sing-box core. The WanX name and
logo are not covered by this license.
