#!/system/bin/sh
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# Motorola Edge 70 Fusion (marvel, SM7635/volcano) recovery touch bring-up.
#
# marvel uses the Motorola "MMI" touch stack with a Goodix BRL controller.
# goodix_brl_mmi / goodix_fod_mmi / rbs_fod_mmi are deliberately listed in
# modules.blocklist (the stock ROM loads the right touch driver on demand after
# probing the panel), so recovery has to pull the chain in explicitly and in
# dependency order.
#
# Gold commit (a16xm): "kernel-modules: exclude GKI kernel modules" +
#                      "init: add a catch to prevent re-execution"
#

LOG_TAG="marvel_touch"
log() { echo "$LOG_TAG: $*"; }

# Bail out if a previous run already loaded the stack.
if [ "$(getprop twrp.marvel.touch.loaded)" = "1" ]; then
    log "already loaded, skipping"
    exit 0
fi

MODULE_DIRS="/vendor/lib/modules /vendor_dlkm/lib/modules /lib/modules /system/lib/modules /system_dlkm/lib/modules"

# Dependency order matters: mmi_info/mmi_relay must be up before touchscreen_mmi,
# and touchscreen_mmi before the controller driver.
TOUCH_MODULES="mmi_annotate mmi_info mmi_relay panel_event_notifier sensors_class touchscreen_mmi goodix_brl_mmi goodix_fod_mmi rbs_fod_mmi"

is_loaded() {
    grep -q "^$1 " /proc/modules 2>/dev/null
}

for mod in $TOUCH_MODULES; do
    is_loaded "$mod" && continue
    for dir in $MODULE_DIRS; do
        ko="$dir/$mod.ko"
        if [ -f "$ko" ]; then
            if insmod "$ko" 2>/dev/null; then
                log "loaded $mod from $dir"
            else
                log "insmod $mod failed"
            fi
            break
        fi
    done
done

# Give the input subsystem a moment to register the touch device.
i=0
while [ $i -lt 10 ]; do
    if grep -qiE "goodix|touchscreen|mmi" /proc/bus/input/devices 2>/dev/null; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

setprop twrp.marvel.touch.loaded 1
log "done"
exit 0
