#!/usr/bin/env bash
# Builds the sing-box core (libbox) via gomobile and drops it into the native projects.
#
#   scripts/build_libbox.sh android   -> android/app/libs/libbox.aar
#   scripts/build_libbox.sh apple     -> ios/Frameworks/Libbox.xcframework (dynamic, slim)
#
# Requirements: Go (version required by the sing-box release), Android NDK
# (ANDROID_NDK_HOME) for android, Xcode for apple.
set -euo pipefail

TARGET="${1:?usage: $0 android|apple}"
SING_BOX_VERSION="${SING_BOX_VERSION:-v1.14.1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build/sing-box"

if [[ ! -d "$WORK" ]]; then
  git clone --depth 1 --branch "$SING_BOX_VERSION" https://github.com/SagerNet/sing-box.git "$WORK"
fi

cd "$WORK"
# gomobile shells out to gobind, which go install puts in GOPATH/bin.
export PATH="$(go env GOPATH)/bin:$PATH"
# Installs SagerNet's gomobile fork, which libbox requires.
make lib_install

# Only the features WanX uses are compiled in: gVisor (TUN stack), QUIC
# (Hysteria2/TUIC), uTLS/Reality and the Clash API (latency test). The
# upstream build also adds Tailscale, Naive/cronet, WireGuard, OpenVPN,
# OpenConnect, USB/IP and DHCP. Add a tag here to bring a feature back.
SLIM_TAGS="with_gvisor,with_quic,with_utls,with_clash_api,badlinkname,tfogo_checklinkname0"
LDFLAGS="-X github.com/sagernet/sing-box/constant.Version=${SING_BOX_VERSION#v} -X runtime.godebugDefault=multipathtcp=0,tlssha1=1 -checklinkname=0 -s -w -buildid="

# Android: slim libbox.aar (same Java package as upstream: io.nekohasekai.libbox).
build_android() {
  gomobile bind -v -o libbox.aar -target android -androidapi 24 \
    -javapkg=io.nekohasekai -libname=box -trimpath -ldflags "$LDFLAGS" \
    -tags "$SLIM_TAGS" ./experimental/libbox
  mkdir -p "$ROOT/android/app/libs"
  cp libbox.aar "$ROOT/android/app/libs/"
}

# iOS: a slim, dynamic Libbox.xcframework.
# - gomobile emits a static library; the app and the PacketTunnel extension
#   would each embed a full copy. It is relinked as a dynamic framework that
#   Runner embeds once and the extension loads from the app bundle.
APPLE_TAGS="$SLIM_TAGS,grpcnotrace"
IOS_MIN="15.0"

build_apple() {
  local out="$WORK/apple-build"
  rm -rf "$out" && mkdir -p "$out"
  gomobile bind -v -o "$out/static/Libbox.xcframework" -target ios,iossimulator \
    -libname=box -tags-not-macos=with_low_memory -iosversion="$IOS_MIN" -trimpath \
    -ldflags "$LDFLAGS" \
    -tags "$APPLE_TAGS" ./experimental/libbox

  local device sim
  device=$(make_dynamic "$out/static/Libbox.xcframework/ios-arm64" iphoneos "arm64" "$out/device")
  sim=$(make_dynamic "$out/static/Libbox.xcframework/ios-arm64_x86_64-simulator" iphonesimulator "arm64 x86_64" "$out/sim")
  xcodebuild -create-xcframework -framework "$device" -framework "$sim" -output "$out/Libbox.xcframework" >/dev/null

  mkdir -p "$ROOT/ios/Frameworks"
  rm -rf "$ROOT/ios/Frameworks/Libbox.xcframework"
  cp -R "$out/Libbox.xcframework" "$ROOT/ios/Frameworks/"
}

# make_dynamic <static slice dir> <sdk> "<archs>" <out dir> → prints framework path
make_dynamic() {
  local slice="$1" sdk="$2" archs="$3" dest="$4"
  local src="$slice/Libbox.framework"
  local fw="$dest/Libbox.framework"
  local lib
  lib=$(readlink -f "$src/Libbox")
  mkdir -p "$fw/Headers" "$fw/Modules"
  cp "$src"/Headers/*.h "$fw/Headers/"
  printf 'framework module "Libbox" {\n  header "Libbox.h"\n  export *\n}\n' > "$fw/Modules/module.modulemap"

  local target_suffix="" thin=()
  [[ "$sdk" == iphonesimulator ]] && target_suffix="-simulator"
  for arch in $archs; do
    lipo "$lib" -thin "$arch" -output "$dest/libbox-$arch.a" 2>/dev/null || cp "$lib" "$dest/libbox-$arch.a"
    xcrun -sdk "$sdk" clang -target "$arch-apple-ios$IOS_MIN$target_suffix" -dynamiclib \
      -Wl,-all_load "$dest/libbox-$arch.a" -o "$dest/Libbox-$arch" \
      -install_name @rpath/Libbox.framework/Libbox \
      -framework Foundation -framework Security -framework UIKit -framework SystemConfiguration \
      -framework CoreFoundation -framework Network -lresolv
    strip -x "$dest/Libbox-$arch"
    thin+=("$dest/Libbox-$arch")
  done
  lipo -create "${thin[@]}" -output "$fw/Libbox"

  local platform=iPhoneOS
  [[ "$sdk" == iphonesimulator ]] && platform=iPhoneSimulator
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Libbox</string>
  <key>CFBundleIdentifier</key><string>com.wanx.Libbox</string>
  <key>CFBundleName</key><string>Libbox</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>${SING_BOX_VERSION#v}</string>
  <key>CFBundleVersion</key><string>${SING_BOX_VERSION#v}</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>$IOS_MIN</string>
</dict>
</plist>
PLIST
  echo "$fw"
}

case "$TARGET" in
  android)
    build_android
    ;;
  apple)
    build_apple
    ;;
  *)
    echo "unknown target: $TARGET" >&2
    exit 1
    ;;
esac

echo "libbox ($SING_BOX_VERSION) built for $TARGET"
