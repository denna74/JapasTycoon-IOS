#!/bin/bash
#
# Builds the GodotUnityAds iOS plugin used by JapasTycoon.
#
# Produces:
#   bin/unity-ads-bridge.release.xcframework   (the Godot bridge static library)
#   vendor/UnityAds.xcframework                (Unity Ads iOS SDK, fetched + cached)
#
# This script must run on macOS with Xcode and Python/SCons (the macos-latest
# GitHub Action runner satisfies all of these). It follows the canonical
# godot-ios-plugins build path: generate the Godot engine headers from the
# 4.6 source, then compile the plugin's Objective-C++ against them.
#
set -euo pipefail

GODOT_TAG="4.6-stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export PATH="$PATH:/opt/homebrew/bin"

# ---------------------------------------------------------------------------
# 1. Fetch the Unity Ads iOS SDK framework (UnityAds.xcframework)
# ---------------------------------------------------------------------------
# Unity publishes a versioned xcframework. The exact tarball URL can drift; if
# this download fails, drop the pre-downloaded `vendor/UnityAds.xcframework`
# into ios/plugins/unity-ads/vendor/ and this step is skipped.
UNITY_ADS_VERSION="${UNITY_ADS_VERSION:-4.18.0}"
VENDOR_DIR="$SCRIPT_DIR/vendor"
mkdir -p "$VENDOR_DIR"

if [ ! -d "$VENDOR_DIR/UnityAds.xcframework" ]; then
    echo "==> Fetching Unity Ads iOS SDK $UNITY_ADS_VERSION"
    # Unity hosts per-version zip bundles. Locate the current URL if this one
    # 404s; place the framework into vendor/UnityAds.xcframework to bypass.
    URL="${UNITY_ADS_SDK_URL:-https://github.com/Unity-Technologies/unity-ads-ios/archive/refs/heads/master.zip}"
    TMP="$(mktemp -d)"
    curl -L --fail -o "$TMP/unityads.zip" "$URL"
    unzip -q "$TMP/unityads.zip" -d "$TMP"
    cp -R "$TMP"/*/UnityAds.*.xcframework "$VENDOR_DIR/UnityAds.xcframework" 2>/dev/null \
        || cp -R "$TMP"/UnityAds.*.xcframework "$VENDOR_DIR/UnityAds.xcframework" 2>/dev/null \
        || { echo "ERROR: could not locate UnityAds.xcframework in $URL"; exit 1; }
    rm -rf "$TMP"
else
    echo "==> Reusing cached UnityAds.xcframework"
fi

# ---------------------------------------------------------------------------
# 2. Build the Godot bridge library
# ---------------------------------------------------------------------------
# The bridge is compiled against the Godot 4.6 engine headers using the
# godot-ios-plugins SConstruct, which we vendor here.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Cloning godot-ios-plugins (build harness)"
git clone --recursive --depth 1 https://github.com/godotengine/godot-ios-plugins.git "$WORK/godot-ios-plugins"
cd "$WORK/godot-ios-plugins"

# Point the Godot submodule at the 4.6 tag and generate headers.
cd godot
git fetch --depth 1 origin tag "$GODOT_TAG"
git checkout "$GODOT_TAG"
cd ..

# Install the plugin's source files into the plugin harness.
PLUGIN_DIR="$WORK/godot-ios-plugins/plugins/godot_unity_ads"
mkdir -p "$PLUGIN_DIR"
cp "$SCRIPT_DIR/src/GodotUnityAds.h" "$SCRIPT_DIR/src/GodotUnityAds.mm" "$PLUGIN_DIR/"
cat > "$PLUGIN_DIR/GodotUnityAdsPlugin.gdip" <<'EOF'
[config]
name="UnityAds"
binaries=["bin/unity-ads-bridge.release.xcframework"]
initialization="register_godot_unity_ads_types"
deinitialization="unregister_godot_unity_ads_types"
restart_if_changed=true
EOF

echo "==> Compiling bridge (arm64 device + simulators)"
# The plugin name passed to scons must match the source-file basename used by
# the SConstruct. We build release only (test-flight release export).
PLUGIN_NAME="godot_unity_ads"
scons target=release_debug arch=arm64 plugin=$PLUGIN_NAME version=4.6
scons target=release_debug arch=arm64 simulator=yes plugin=$PLUGIN_NAME version=4.6

lipo -create \
    "./bin/lib$PLUGIN_NAME.arm64-ios.release_debug.a" \
    -output "./bin/$PLUGIN_NAME-device.release_debug.a"
lipo -create \
    "./bin/lib$PLUGIN_NAME.arm64-simulator.release_debug.a" \
    -output "./bin/$PLUGIN_NAME-simulator.release_debug.a"

xcodebuild -create-xcframework \
    -library "./bin/$PLUGIN_NAME-device.release_debug.a" \
    -library "./bin/$PLUGIN_NAME-simulator.release_debug.a" \
    -output "$ROOT_DIR/ios/plugins/unity-ads/bin/unity-ads-bridge.xcframework"

echo "==> Build complete: ios/plugins/unity-ads/bin/unity-ads-bridge.xcframework"
