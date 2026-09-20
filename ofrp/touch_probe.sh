#!/system/bin/sh
#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# Motorola Touchscreen Kernel Module Loader for Edge 70 Fusion (marvel)
#

# Probe standard and Motorola touch drivers via modprobe if available
modprobe touchscreen_mmi 2>/dev/null || true
modprobe goodix_brl_mmi 2>/dev/null || true
modprobe focaltech_v3_4 2>/dev/null || true
modprobe goodix_fod_mmi 2>/dev/null || true
modprobe goodix_core 2>/dev/null || true
modprobe focaltech_touch 2>/dev/null || true
modprobe novatek_touch 2>/dev/null || true
modprobe synaptics_tcm2 2>/dev/null || true

# Probe touch driver modules by direct path lookup
MODULE_DIRS="/vendor/lib/modules /vendor_dlkm/lib/modules /system/lib/modules /system_dlkm/lib/modules /vendor/lib/modules/1.1"

for dir in $MODULE_DIRS; do
    if [ -d "$dir" ]; then
        for mod in touchscreen_mmi.ko goodix_brl_mmi.ko focaltech_v3_4.ko goodix_fod_mmi.ko goodix_core.ko focaltech_touch.ko novatek_touch.ko synaptics_tcm2.ko; do
            if [ -f "$dir/$mod" ]; then
                insmod "$dir/$mod" 2>/dev/null || true
            fi
        done
    fi
done

exit 0
