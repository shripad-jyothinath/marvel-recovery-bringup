#!/usr/bin/env bash
#
# Install this TWRP device tree into a TWRP source tree.
#
# TWRP is built from its own manifest (the Evolution X tree is not a TWRP
# tree). Recommended, same as the working cybert build:
#   repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
#   repo sync
#
# Usage:
#   ./apply_twrp.sh /path/to/twrp-source [/path/to/evox-source]
#
set -euo pipefail

TWRP_TOP="${1:?usage: apply_twrp.sh <twrp-source> [evox-source]}"
EVOX="${2:-/serverhive/shripad/evox}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DT="$TWRP_TOP/device/motorola/marvel"

echo "==> installing tree into $DT"
mkdir -p "$DT"
cp -r "$SRC/." "$DT/"
chmod +x "$DT/recovery/touch_probe.sh" "$DT/recovery/root/system/bin/load-mod.sh"

echo "==> copying the volcano kernel module set from $EVOX"
EVOX_DT="$EVOX/device/motorola/marvel"
if [ -d "$EVOX_DT/modules" ]; then
    mkdir -p "$DT/modules"
    cp -r "$EVOX_DT/modules/vendor_dlkm" "$DT/modules/"
    cp -r "$EVOX_DT/modules/vendor_boot" "$DT/modules/"
    cp "$EVOX_DT/modules.load.recovery" \
       "$EVOX_DT/modules.load.vendor_boot" \
       "$EVOX_DT/modules.load" \
       "$EVOX_DT/modules.blocklist" \
       "$EVOX_DT/modules.systemdlkm_blocklist" \
       "$EVOX_DT/modules.load.system_dlkm" "$DT/"
    echo "    vendor_dlkm: $(ls "$DT/modules/vendor_dlkm" | wc -l) modules"
    echo "    vendor_boot: $(ls "$DT/modules/vendor_boot" | wc -l) modules"
else
    echo "!! $EVOX_DT/modules not found - copy the volcano module set manually"
    exit 1
fi

# Prebuilt kernel / dtb / dtbo (marvel ships a prebuilt GKI kernel)
for f in kernel kernel-headers.tar.gz dtbo.img; do
    [ -f "$EVOX_DT/prebuilt/$f" ] && cp "$EVOX_DT/prebuilt/$f" "$DT/prebuilt/" || true
done
[ -d "$EVOX_DT/prebuilt/dtb" ] && cp -r "$EVOX_DT/prebuilt/dtb" "$DT/prebuilt/" || true

echo
echo "==> build:"
echo "    cd $TWRP_TOP"
echo "    source build/envsetup.sh"
echo "    lunch twrp_marvel-eng"
echo "    mka recoveryimage"
