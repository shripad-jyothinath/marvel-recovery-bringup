# 07 — Reference trees and "gold" commits

Every commit message below was read and mined for the fix work. Grouped by relevance.

## Same SoC (SM7635 "volcano")

### `chkndrp/device_xiaomi_amethyst-recovery` — Redmi Note 14 Pro+, OFRP
The only other SM7635 recovery tree found. Directly comparable platform behaviour.

```
BoardConfig.mk: explicitly set TARGET_USE_CUSTOM_LUN_FILE_PATH to prevent issues
init: symlink bootdevice earlier
init: setup cpuset to make task_profiles work
init: append task_profiles to services
recovery.fstab: replace fsync=nobarrier with fsync=posix
init: do more waiting for stability
init: do filesystem tuning earlier
init: add a catch to the twrp.modules.loaded block to prevent re-execution
init: stop forcing the legacy sysfs fallback
twrp.flags: add/adjust even more partitions
prebuilt: remove all kernel module prebuilts
vendorsetup.sh: bundle magisk into the ramdisk
```

## Official TeamWin — Qualcomm / A-B / GKI

### `TeamWin/android_device_oneplus_lemonadep` — SM8350, A/B (most complete modern reference)
```
lemonadep: use los default qcom usb init rc
lemonadep: cleanup usb init and reduce wait time for sysfs files
lemonadep: switch to inbuilt TWRP logic for loading modules
lemonadep: add missing firmware files and let TWRP load kernel modules
lemonadep: wait before starting vibration and health service otherwise it can result in lags
lemonadep: * remove quotes from TW_BRIGHTNESS_PATH
            * include lpdump
            * include lptools
            * include fb2png
lemonadep: add vendor_boot, dtbo and firmware to backup options and add fstab entries for oos
lemonadep: exclude /data/fonts and /data/nandswap from backup
lemonadep: use aidl vibrator
lemonadep: fix vibration
lemonadep: switch to boot hal 1.2 and overwrite timestamps on boot
lemonadep: update fix modem not flashable in fastbootd
lemonadep: remove incompatible vintf fragments that are loaded from vendor_boot ramdisk
lemonadep: Fix battery and USB OTG detection
add dtbo and vendor_boot to fstab
switch to functionfs and cleanup usb config
improve module loading logic
```

### `TeamWin/android_device_motorola_genevn` — Motorola, Qualcomm (closest vendor match)
```
touchscreen: support ilitek touch panel variants
fstab: support USB OTG and External SD Cards
eqs: add spdaemon and sec_nvm services
eqs: keymaster: make sure to start km 4.1 when km 4.0 sb is started
eqs: add spu 1.1/2.0 and dependencies
eqs: dont disable spu for gatekeeper
hiphi: recovery/root: Implement proper modules loading
hiphi: Add TARGET_USE_CUSTOM_LUN_FILE_PATH
hiphi: Exclude the Default USB Init
hiphi: Let qcom common decryption tree handle decryption
hiphi: Use fscrypt policy v2
hiphi: Enable TW_INCLUDE_CRYPTO
hiphi: recovery/root: Load ADSP firmware
hiphi: recovery/root: Set permissive
hiphi: Move recovery.fstab to system/etc directory
hiphi: Import TWRP flags and refactor fstab
hiphi: Advertise EDL mode
hiphi: Enable TARGET_RECOVERY_QCOM_RTC_FIX
hiphi: Render at 60 FPS
hiphi: Define brightness-related flags for TWRP
hiphi: Disable blank screen on boot
hiphi: Add masking to hide notch cutout
hiphi: Exclude fonts data from backup
hiphi: Recreate /data/media folder after format data
hiphi: Build F2FS recovery utilities
hiphi: Build userdata image as f2fs
hiphi: motorola_dynamic_partitions -> qti_dynamic_partitions
hiphi: Inherit emulated storage
hiphi: Build resetprop and libresetprop
hiphi: Adding GSI keys
hiphi: Use RSA4096 key also for vbmeta_system
hiphi: Spoof vendor security patch with anti-rollback hack
hiphi: Introduce device and model spoofing
hiphi: Set shipping API level
hiphi: Remove TW_USE_TOOLBOX
hiphi: Kill BOARD_HAS_LARGE_FILESYSTEM
hiphi: Update to Boot Control HAL v1.2
hiphi: Add bootctrl HAL and gpt-utils
hiphi: Build fastbootd
hiphi: Rebrand to TWRP
```

### `TeamWin/android_device_nothing_pacman` — modern module handling
```
Pacman: Fix vendor ramdisk kernel modules handling
Pacman: Drop module loader files from recovery/root/vendor/lib/modules
Pacman: Integrate kernel modules from NOS 3.0 into tree
Pacman: TWRP: Define TWRP specific flags
Pacman: TWRP: Add vendor modules
Pacman: TWRP: Build in bootctrl
Pacman: TWRP: Add init.mt6886.usb.rc
Pacman: TWRP: Change TARGET_RECOVERY_PIXEL_FORMAT to RGBX_8888
```

### `TeamWin/android_device_xiaomi_pissarro` — MT6877 (closest official Dimensity)
```
system.prop: ro.crypto.volume.filenames_mode=aes-256-cts
init.recovery.*.rc: wait /dev/block/platform/soc/<ufshci> + symlink /dev/block/bootdevice
twrp.flags: per-partition flags incl. slotselect and flashimg=1
```

### `TeamWin/android_device_samsung_a16xm` — MT6835, Dec 2025
```
init: Load DLKM modules separately to avoid issues when the user has a custom kernel that breaks the ABI.
init: symlink the block devices to /dev/block/by-name and /dev/block/bootdevice
init: add USB OTG switcher service for automatic role switching in recovery
BoardConfig: enable model name for device ID
BoardConfig: Exclude APEX images to fix the mounting errors in the logs
BoardConfig: Force the TWRP to 64-bit and drop the legacy 32-bit support
BoardConfig: remove double quotes from every variable to fix build errors
kernel-modules: exclude GKI kernel modules
kernel-modules: added touch screen firmware, kernel modules and depmod configs
kernel-modules: imported modules to recovery-root/lib from the stock vendor_boot.img
twrp: fix broken graphics            -> RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH
twrp: include fastbootd mode
```

## Motorola (the cybert tree — used for Motorola-specific behaviour)

`cybert_twrp` (Moto Edge 60 Pro, MT6897) is the working Motorola TWRP reference:

- unified MMI touch layer (`touchscreen_u_mmi`) + per-chip drivers
  (`goodix_brl_u_mmi`, `focaltech_touch_v3_u_mmi`, `cps4038_mmi`) force-loaded because of
  `modules.blocklist`
- `RECOVERY_KERNEL_MODULES` + `TW_LOAD_VENDOR_MODULES*` pattern
- `twrp.flags` covering every partition including vendor calibration/protection partitions
- `init.recovery.mt6897.rc` + per-platform USB configfs
- **but** its recovery lives in `vendor_boot` — see `docs/04-cybert-vs-marvel.md`

## Upstream of the marvel reference trees

`soytony/android_device_motorola_roadstr` (branch `lineage-23.2`) — this is where the marvel
reference trees came from.

```
roadstr: Rename sun-common to sm7750-common in dependencies     <- the "sun" naming origin
roadstr: validate recovery build with prebuilt headers
fix(touch): wake directly on double tap
fix(avb): set rollback index floor
fix(display): expose all panel refresh modes
fix(display): avoid idle brightness step
fix(gpio): gpio key mapping
roadstr: use legacy double tap backend
roadstr: use sysfs double-tap sensor
roadstr: arm double tap through power HAL
```

Key takeaway: `sm7750-common` is the **renamed `sun-common` (SM8750)** tree. marvel (SM7635
"volcano") was derived from an SM8750 reference, which is the origin of the `sun`/`oryon`/
`roadstr` leftovers and the roadstr module lists.
