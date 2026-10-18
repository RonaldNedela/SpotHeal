#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DOWNLOADS_DIR="/Users/Ronci/Downloads"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"

LDID="ldid"
if [ -x "/opt/homebrew/bin/ldid" ]; then
    LDID="/opt/homebrew/bin/ldid"
fi

DPKG_DEB="dpkg-deb"
if [ -x "/opt/homebrew/bin/dpkg-deb" ]; then
    DPKG_DEB="/opt/homebrew/bin/dpkg-deb"
fi

echo "=== Building SpotHeal (iPad Hotspot Luminance Mask) ==="
echo "SDK: ${SDK_PATH}"
echo "ldid: ${LDID}"
echo "dpkg-deb: ${DPKG_DEB}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/bin"

# 1. Compile SpringBoard dylib (fat arm64 + arm64e)
echo "Compiling SpotHeal.dylib (SpringBoard hook)..."
xcrun -sdk iphoneos clang \
    -arch arm64 -arch arm64e \
    -miphoneos-version-min=12.0 \
    -isysroot "${SDK_PATH}" \
    -fobjc-arc -O3 -dynamiclib \
    -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore \
    "${SCRIPT_DIR}/src/SpotHeal.m" \
    -o "${BUILD_DIR}/bin/SpotHeal.dylib"

"${LDID}" -S "${BUILD_DIR}/bin/SpotHeal.dylib"
echo "SpotHeal.dylib compiled and signed successfully."

# 2. Compile PreferenceBundle binary (fat arm64 + arm64e)
echo "Compiling SpotHeal PreferenceBundle binary..."
xcrun -sdk iphoneos clang \
    -arch arm64 -arch arm64e \
    -miphoneos-version-min=12.0 \
    -isysroot "${SDK_PATH}" \
    -fobjc-arc -O3 -bundle \
    -I"${SCRIPT_DIR}/src/pref_bundle" \
    -framework Foundation -framework UIKit -framework CoreGraphics \
    "${SCRIPT_DIR}/src/pref_bundle/Preferences.tbd" \
    "${SCRIPT_DIR}/src/pref_bundle/SpotHealRootListController.m" \
    -o "${BUILD_DIR}/bin/SpotHeal"

"${LDID}" -S "${BUILD_DIR}/bin/SpotHeal"
echo "SpotHeal preference binary compiled and signed successfully."

# ==========================================
# 3. Build Rootless DEB (iOS 15 - 18+, Dopamine)
# ==========================================
echo "Staging Rootless package (iphoneos-arm64)..."
STAGE_ROOTLESS="${BUILD_DIR}/stage_rootless"
mkdir -p "${STAGE_ROOTLESS}/DEBIAN"
mkdir -p "${STAGE_ROOTLESS}/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "${STAGE_ROOTLESS}/var/jb/Library/PreferenceLoader/Preferences"
mkdir -p "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle"

cat << 'EOF' > "${STAGE_ROOTLESS}/DEBIAN/control"
Package: com.ronci.spotheal
Name: SpotHeal
Version: 1.0.0
Architecture: iphoneos-arm64
Description: Subtractive luminance compensation mask for iPad display hotspots (white spots above Home button).
Maintainer: Ronci
Author: Ronci
Section: Tweaks
Depends: mobilesubstrate (>= 0.9.5000), preferenceloader
Tag: role::tweaks, purpose::extension
EOF

cat << 'EOF' > "${STAGE_ROOTLESS}/DEBIAN/postinst"
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
    # Close Settings so it picks up the new bundle immediately
    killall -9 Preferences 2>/dev/null || true

    # Tell Cydia / Sileo / Zebra to prompt for Respring
    if [ -n "$CYDIA" ]; then
        cydia_fd=$(echo "$CYDIA" | cut -d' ' -f1)
        if [ -n "$cydia_fd" ]; then
            eval "echo 'finish:restart' >&$cydia_fd" 2>/dev/null || true
        fi
    fi

    # CLI fallback
    if [ -z "$CYDIA" ] && [ -t 1 ]; then
        if [ -x "/var/jb/usr/bin/sbreload" ]; then
            /var/jb/usr/bin/sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        elif command -v sbreload >/dev/null 2>&1; then
            sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        else
            killall -9 SpringBoard 2>/dev/null || true
        fi
    fi
fi

exit 0
EOF
chmod 755 "${STAGE_ROOTLESS}/DEBIAN/postinst"

cat << 'EOF' > "${STAGE_ROOTLESS}/DEBIAN/postrm"
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    killall -9 Preferences 2>/dev/null || true

    if [ -n "$CYDIA" ]; then
        cydia_fd=$(echo "$CYDIA" | cut -d' ' -f1)
        if [ -n "$cydia_fd" ]; then
            eval "echo 'finish:restart' >&$cydia_fd" 2>/dev/null || true
        fi
    fi

    if [ -z "$CYDIA" ] && [ -t 1 ]; then
        if [ -x "/var/jb/usr/bin/sbreload" ]; then
            /var/jb/usr/bin/sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        elif command -v sbreload >/dev/null 2>&1; then
            sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        else
            killall -9 SpringBoard 2>/dev/null || true
        fi
    fi
fi

exit 0
EOF
chmod 755 "${STAGE_ROOTLESS}/DEBIAN/postrm"

# SpringBoard dylib & filter plist
cp "${BUILD_DIR}/bin/SpotHeal.dylib" "${STAGE_ROOTLESS}/var/jb/Library/MobileSubstrate/DynamicLibraries/"
cp "${SCRIPT_DIR}/src/SpotHeal.plist" "${STAGE_ROOTLESS}/var/jb/Library/MobileSubstrate/DynamicLibraries/"

# PreferenceLoader entry (ONLY uniquely named files in shared PreferenceLoader folder)
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/entry.plist" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceLoader/Preferences/SpotHeal.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal.png" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceLoader/Preferences/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal@2x.png" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceLoader/Preferences/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal@3x.png" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceLoader/Preferences/"

# PreferenceBundle files
cp "${BUILD_DIR}/bin/SpotHeal" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Info.plist" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Root.plist" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle/Root.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Root.plist" "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle/SpotHeal.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/"*.png "${STAGE_ROOTLESS}/var/jb/Library/PreferenceBundles/SpotHeal.bundle/"

ROOTLESS_DEB="${BUILD_DIR}/com.ronci.spotheal_1.0.0_iphoneos-arm64.deb"
"${DPKG_DEB}" --root-owner-group -b -Zgzip "${STAGE_ROOTLESS}" "${ROOTLESS_DEB}"
echo "Rootless DEB built: ${ROOTLESS_DEB}"

# ==========================================
# 4. Build Rootful DEB (iOS 12 - 14.8.1)
# ==========================================
echo "Staging Rootful package (iphoneos-arm)..."
STAGE_ROOTFUL="${BUILD_DIR}/stage_rootful"
mkdir -p "${STAGE_ROOTFUL}/DEBIAN"
mkdir -p "${STAGE_ROOTFUL}/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "${STAGE_ROOTFUL}/Library/PreferenceLoader/Preferences"
mkdir -p "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle"

cat << 'EOF' > "${STAGE_ROOTFUL}/DEBIAN/control"
Package: com.ronci.spotheal
Name: SpotHeal
Version: 1.0.0
Architecture: iphoneos-arm
Description: Subtractive luminance compensation mask for iPad display hotspots (white spots above Home button).
Maintainer: Ronci
Author: Ronci
Section: Tweaks
Depends: mobilesubstrate (>= 0.9.5000), preferenceloader
Tag: role::tweaks, purpose::extension
EOF

cat << 'EOF' > "${STAGE_ROOTFUL}/DEBIAN/postinst"
#!/bin/sh
set -e

if [ "$1" = "configure" ]; then
    killall -9 Preferences 2>/dev/null || true

    if [ -n "$CYDIA" ]; then
        cydia_fd=$(echo "$CYDIA" | cut -d' ' -f1)
        if [ -n "$cydia_fd" ]; then
            eval "echo 'finish:restart' >&$cydia_fd" 2>/dev/null || true
        fi
    fi

    if [ -z "$CYDIA" ] && [ -t 1 ]; then
        if command -v sbreload >/dev/null 2>&1; then
            sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        else
            killall -9 SpringBoard 2>/dev/null || true
        fi
    fi
fi

exit 0
EOF
chmod 755 "${STAGE_ROOTFUL}/DEBIAN/postinst"

cat << 'EOF' > "${STAGE_ROOTFUL}/DEBIAN/postrm"
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    killall -9 Preferences 2>/dev/null || true

    if [ -n "$CYDIA" ]; then
        cydia_fd=$(echo "$CYDIA" | cut -d' ' -f1)
        if [ -n "$cydia_fd" ]; then
            eval "echo 'finish:restart' >&$cydia_fd" 2>/dev/null || true
        fi
    fi

    if [ -z "$CYDIA" ] && [ -t 1 ]; then
        if command -v sbreload >/dev/null 2>&1; then
            sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null || true
        else
            killall -9 SpringBoard 2>/dev/null || true
        fi
    fi
fi

exit 0
EOF
chmod 755 "${STAGE_ROOTFUL}/DEBIAN/postrm"

# SpringBoard dylib & filter plist
cp "${BUILD_DIR}/bin/SpotHeal.dylib" "${STAGE_ROOTFUL}/Library/MobileSubstrate/DynamicLibraries/"
cp "${SCRIPT_DIR}/src/SpotHeal.plist" "${STAGE_ROOTFUL}/Library/MobileSubstrate/DynamicLibraries/"

# PreferenceLoader entry (ONLY uniquely named files in shared PreferenceLoader folder)
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/entry.plist" "${STAGE_ROOTFUL}/Library/PreferenceLoader/Preferences/SpotHeal.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal.png" "${STAGE_ROOTFUL}/Library/PreferenceLoader/Preferences/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal@2x.png" "${STAGE_ROOTFUL}/Library/PreferenceLoader/Preferences/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/SpotHeal@3x.png" "${STAGE_ROOTFUL}/Library/PreferenceLoader/Preferences/"

# PreferenceBundle files
cp "${BUILD_DIR}/bin/SpotHeal" "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Info.plist" "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle/"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Root.plist" "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle/Root.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/Root.plist" "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle/SpotHeal.plist"
cp "${SCRIPT_DIR}/src/pref_bundle/Resources/"*.png "${STAGE_ROOTFUL}/Library/PreferenceBundles/SpotHeal.bundle/"

ROOTFUL_DEB="${BUILD_DIR}/com.ronci.spotheal_1.0.0_iphoneos-arm.deb"
"${DPKG_DEB}" --root-owner-group -b -Zgzip "${STAGE_ROOTFUL}" "${ROOTFUL_DEB}"
echo "Rootful DEB built: ${ROOTFUL_DEB}"

# 5. Export to Downloads
cp "${ROOTLESS_DEB}" "${DOWNLOADS_DIR}/"
cp "${ROOTFUL_DEB}" "${DOWNLOADS_DIR}/"

echo "=== Packaging Complete ==="
echo "Rootless: ${DOWNLOADS_DIR}/com.ronci.spotheal_1.0.0_iphoneos-arm64.deb"
echo "Rootful:  ${DOWNLOADS_DIR}/com.ronci.spotheal_1.0.0_iphoneos-arm.deb"
ls -la "${DOWNLOADS_DIR}/com.ronci.spotheal_1.0.0_iphoneos-"*.deb
