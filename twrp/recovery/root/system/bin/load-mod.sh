#!/system/bin/sh
#
# Copyright (C) 2026 The Team Win Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# TWRP module loader for marvel.
#
# gold: lemonadep "switch to inbuilt TWRP logic for loading modules" and
#       genevn "Implement proper modules loading".
#
# TWRP's inbuilt loader already handles the vendor/boot module lists; this
# script only force-loads what modules.blocklist deliberately keeps out (the
# Motorola touch controllers) so recovery input works.
#

LOG_TAG="marvel-load-mod"
log() { echo "$LOG_TAG: $*"; }

is_loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

MODULE_DIRS="/vendor/lib/modules /vendor_dlkm/lib/modules /lib/modules /system/lib/modules /system_dlkm/lib/modules"

# Motorola MMI touch chain, in dependency order.
TOUCH_MODULES="mmi_info mmi_relay mmi_annotate sensors_class touchscreen_mmi goodix_brl_mmi goodix_fod_mmi rbs_fod_mmi"

for mod in $TOUCH_MODULES; do
    is_loaded "$mod" && continue
    for dir in $MODULE_DIRS; do
        if [ -f "$dir/$mod.ko" ]; then
            insmod "$dir/$mod.ko" 2>/dev/null && log "loaded $mod"
            break
        fi
    done
done

exit 0
