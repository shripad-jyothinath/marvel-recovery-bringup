#!/usr/bin/env bash
#
# Apply the rewritten marvel OFRP tree onto the `ofrp` branch.
# Run on the build server, with this directory copied to ~/marvel_ofrp_v2
#
set -euo pipefail

EVOX=/serverhive/shripad/evox
SRC="${1:-$HOME/marvel_ofrp_v2}"
DT="$EVOX/device/motorola/marvel"

cd "$EVOX"

echo "==> switching to the ofrp branch"
git -C "$DT" fetch --all || true
git -C "$DT" checkout ofrp

echo "==> taking the volcano module config from evox-a17"
# The ofrp branch currently carries roadstr/SM8750 (\"sun\") module lists and has
# no modules/ directory at all. Pull the correct volcano set from evox-a17.
git -C "$DT" checkout evox-a17 -- \
    modules.load.recovery \
    modules.load.vendor_boot \
    modules.load \
    modules.blocklist \
    modules.systemdlkm_blocklist \
    modules/vendor_dlkm \
    modules/vendor_boot

echo "==> installing rewritten files"
cp -v "$SRC/BoardConfig.mk"                        "$DT/BoardConfig.mk"
cp -v "$SRC/device.mk"                             "$DT/device.mk"
cp -v "$SRC/orangefox_marvel.mk"                   "$DT/orangefox_marvel.mk"
cp -v "$SRC/system.prop"                           "$DT/system.prop"
mkdir -p "$DT/recovery/root/system/etc"
cp -v "$SRC/recovery/root/init.recovery.qcom.rc"   "$DT/recovery/root/init.recovery.qcom.rc"
cp -v "$SRC/recovery/root/system/etc/twrp.flags"   "$DT/recovery/root/system/etc/twrp.flags"
cp -v "$SRC/recovery/touch_probe.sh"               "$DT/recovery/touch_probe.sh"
chmod +x "$DT/recovery/touch_probe.sh"

echo
echo "==> sanity check: modules present?"
ls "$DT/modules/vendor_dlkm" | wc -l
grep -c volcano "$DT/modules.load.recovery" || true

echo
echo "==> now build:"
echo "    source build/envsetup.sh && lunch orangefox_marvel-eng && mka recoveryimage"
