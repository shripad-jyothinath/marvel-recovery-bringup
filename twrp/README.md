# TWRP device tree — Motorola Edge 70 Fusion (`marvel` / XT2605)

Pure **TeamWin Recovery Project** tree (not OrangeFox). Builds `twrp_marvel`.

| | |
|---|---|
| SoC | Qualcomm **SM7635 "volcano"** (Kryo), GKI **6.1** (`android14-6.1`) |
| Stock OS | Android 16 (`motorola/marvel_gh/marvel:16/W2WE6.56-98-19`) |
| Partitions | A/B, dynamic `super`, **dedicated `recovery` partition (128 MB)** |
| Recovery | ramdisk-only image (kernel comes from `boot`) |

---

## Reference policy

| Area | Source |
|---|---|
| Qualcomm / Snapdragon / A-B / GKI / crypto / USB | **official TeamWin trees** |
| Motorola-specific (MMI touch, panel, mmi init) | **cybert tree** (Moto Edge 60 Pro) |

Official TeamWin trees used:

- **`TeamWin/android_device_oneplus_lemonadep`** — SM8350, A/B, Qualcomm, most complete modern reference
- **`TeamWin/android_device_motorola_genevn`** — Motorola Qualcomm (closest vendor match)
- **`TeamWin/android_device_nothing_pacman`** — modern module handling
- `TeamWin/android_device_xiaomi_pissarro` — crypto props

---

## Why cybert works but marvel didn't

This is the single most important difference, and it is **not** about MediaTek vs Qualcomm.

`cybert_twrp/BoardConfig.mk`:

```make
115: TW_HAS_NO_RECOVERY_PARTITION := true
128: BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
129: BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
```

…and the cybert README flashes **`fastboot flash vendor_boot_a vendor_boot.img`**.

So cybert's recovery is a **vendor_boot recovery**: the recovery ramdisk *and every kernel
module* ride inside `vendor_boot`, and the bootloader always loads the vendor ramdisk. That is
why cybert's touch, USB and everything else "just works" — the modules are simply there.

**marvel is the opposite layout:**

| | cybert | marvel |
|---|---|---|
| recovery location | `vendor_boot` | **dedicated `recovery` partition (128 MB)** |
| recovery image | vendor ramdisk (with modules) | **ramdisk-only** (`BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`) |
| kernel source for recovery | prebuilt kernel in vendor_boot | kernel taken from `boot` by ABL |
| `vendor_boot` loaded during recovery | yes | **no** |
| where recovery modules must live | vendor ramdisk | **the recovery ramdisk itself** |

Because marvel's recovery boots **standalone** from its own partition, its ramdisk must be
self-contained. The old tree put **0 `.ko` files** in it, so:

- no `touchscreen_mmi` / `goodix_brl_mmi` → no touch, no volume-key input
- no `dwc3-msm` + `usb_f_*` → no USB gadget → no adb, no MTP, no fastbootd, and Windows
  never even enumerates the device

Display survived because the panel/DRM path is brought up early, which is why the UI appeared
with everything else dead.

**So "just copy cybert" cannot work.** On cybert the modules are free (vendor ramdisk); on
marvel you must explicitly package them:

```make
BOARD_VENDOR_KERNEL_MODULES        := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)
BOARD_RECOVERY_KERNEL_MODULES      := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
```

> **Do not** set `TW_HAS_NO_RECOVERY_PARTITION` on marvel. TWRP treats it as
> *defined = true*, so even `:= false` makes TWRP believe there is no recovery partition.

### cybert → marvel mapping

| cybert (MT6897, working) | marvel (SM7635) |
|---|---|
| `prebuilt/modules/vendor/*.ko` | `modules/vendor_dlkm/*.ko` |
| `prebuilt/modules/vendor_ramdisk/*.ko` | `modules/vendor_boot/*.ko` |
| `RECOVERY_KERNEL_MODULES := mmi_info mmi_relay sensors_class touchscreen_u_mmi focaltech_touch_v3_u_mmi goodix_brl_u_mmi` | `mmi_info mmi_relay mmi_annotate sensors_class touchscreen_mmi goodix_brl_mmi goodix_fod_mmi rbs_fod_mmi` |
| `TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI` / `TW_LOAD_VENDOR_BOOT_MODULES` / `TW_LOAD_VENDOR_MODULES` | **same** |
| force-load because `goodix_brl_mmi` etc. are in `modules.blocklist` | **same** |
| recovery in **vendor_boot** | **dedicated recovery partition** → bundle modules in the ramdisk |
| `init.recovery.mt6897.rc` + MTK configfs USB + `tee.rc`/`trustonic.rc` | Qualcomm `init.recovery.qcom.rc` + TWRP's default qcom USB init |
| `TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness` | `/sys/class/backlight/panel0-backlight/brightness` |
| `TW_INPUT_BLACKLIST := "hbtp_vm"` (MTK touch node) | `"goodix_brl_mmi\|hbtp_vm"` |
| `TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888` | `RGBX_8888` |
| `mtk_plpath_utils`, MTK `bootctrl`, `t-base-tui` | QTI `bootctrl`/`gpt-utils`, QSEE keymint |
| MobiCore/TEE (`tzapp`, `.drbin`, Trustonic) | QTI QSEE keymint (+ Thales StrongBox/SPU) |

### Alternative (not recommended)

You *could* switch marvel to cybert's model (recovery in `vendor_boot`,
`TW_HAS_NO_RECOVERY_PARTITION := true`, flash `vendor_boot`). But marvel's bootloader has a
dedicated "Recovery mode" entry pointing at the `recovery` partition, so it would likely keep
booting that. Keeping the dedicated partition and making its ramdisk self-contained — what this
tree does — is the correct path.

## The bug this tree fixes

The previous tree only set the module **load lists** and never the module lists
themselves, and the branch had no `modules/` directory:

```make
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(shell cat modules.load)          # names only
# ... no BOARD_VENDOR_KERNEL_MODULES / BOARD_VENDOR_RAMDISK_KERNEL_MODULES
```

`build-image-kernel-modules-dir` copies nothing when `BOARD_<X>_KERNEL_MODULES`
is empty → `recovery.img` contained **0 `.ko` files** → no `touchscreen_mmi` /
`goodix_brl_mmi` (touch), no `dwc3-msm` + `usb_f_*` (USB gadget → no adb/MTP).
Display survived because the panel/DRM path comes up early.

This tree packages the modules and makes recovery self-contained:

```make
BOARD_VENDOR_KERNEL_MODULES        := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)
BOARD_RECOVERY_KERNEL_MODULES      := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
```

…plus TWRP's inbuilt loader (`TW_LOAD_VENDOR_MODULES*`).

Also fixed:
- module load lists must be the **volcano** lists (the branch carried roadstr/SM8750 `*_sun.ko` lists)
- the init file that starts the touch probe is now actually copied into the ramdisk
- `goodix_brl_mmi` / `goodix_fod_mmi` / `rbs_fod_mmi` are in `modules.blocklist`, so they are force-loaded
- removed `oryon` CPU variant, `androidboot.roadstr_init_probe`, MediaTek `hbtp_vm` blacklist
- `dtbo` partition size corrected to the real `34603008`

## Motorola-specific (from cybert)

marvel uses the **MMI touch stack + Goodix BRL** controller:

```
mmi_info → mmi_relay → mmi_annotate → sensors_class → touchscreen_mmi → goodix_brl_mmi
```

(`goodix_fod_mmi`, `rbs_fod_mmi` for the under-display sensor.)

## Qualcomm-specific gold commits applied

- `lemonadep: use los default qcom usb init rc` → keep TWRP's Qualcomm USB init
- `lemonadep: cleanup usb init and reduce wait time for sysfs files`
- `lemonadep: switch to inbuilt TWRP logic for loading modules`
- `lemonadep: add missing firmware files and let TWRP load kernel modules`
- `lemonadep: wait before starting vibration and health service otherwise it can result in lags`
- `lemonadep: remove quotes from TW_BRIGHTNESS_PATH`
- `lemonadep: * include lpdump * include lptools * include fb2png`
- `genevn: Move recovery.fstab to system/etc directory`
- `genevn: Add TARGET_USE_CUSTOM_LUN_FILE_PATH`
- `genevn: Let qcom common decryption tree handle decryption` / `Use fscrypt policy v2`
- `genevn: Advertise EDL mode` / `Enable TARGET_RECOVERY_QCOM_RTC_FIX`
- `genevn: Disable blank screen on boot` / `Render at 60 FPS` / `Add masking to hide notch cutout`
- `genevn: Kill BOARD_HAS_LARGE_FILESYSTEM` / `Build userdata image as f2fs`
- `a16xm: Force the TWRP to 64-bit` / `Exclude APEX images` / `enable model name for device ID`
- `a16xm: kernel-modules: exclude GKI kernel modules`
- `amethyst: recovery.fstab: replace fsync=nobarrier with fsync=posix`

## Encryption framework (SM7635)

Qualcomm **QTI keymint/gatekeeper (QSEE)**, with **Thales StrongBox/Weaver + SPU** on
SKUs that ship an SPU — *not* Trustonic/MobiCore (that's the MediaTek MT6897 answer).

Recovery side: `TW_INCLUDE_CRYPTO_FBE`, `TW_INCLUDE_FBE_METADATA_DECRYPT`,
`BOARD_USES_QCOM_FBE_DECRYPTION`, `TW_USE_FSCRYPT_POLICY := 2`,
`ro.crypto.volume.filenames_mode=aes-256-cts`.

---

## Files

```
AndroidProducts.mk                        lunch: twrp_marvel-eng
twrp_marvel.mk                            PRODUCT_NAME := twrp_marvel
device.mk                                 minimal recovery product config
BoardConfig.mk                            TWRP-only (TW_*), no OF_*/FOX_*
Android.mk / Android.bp
system.prop                               crypto / USB / TEE props
recovery/root/init.recovery.qcom.rc       Qualcomm init + Motorola touch service
recovery/root/system/bin/load-mod.sh      force-load the MMI touch chain
recovery/root/system/etc/recovery.fstab   Qualcomm A/B fstab (both erofs + ext4)
recovery/root/system/etc/twrp.flags       full partition list
recovery/touch_probe.sh                   Motorola Goodix BRL probe
```

## Build

```bash
source build/envsetup.sh
lunch twrp_marvel-eng
mka recoveryimage
```

## Install

```bash
fastboot flash recovery out/target/product/marvel/recovery.img
# then boot recovery from the bootloader menu (Power + Volume Down -> Recovery mode)
```

Flash **only** the recovery partition; `boot` / `init_boot` / `vendor_boot` stay stock.
