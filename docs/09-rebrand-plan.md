# 09 — Rebrand plan: `device_xiaomi_amethyst-recovery` → marvel

Base: **`chkndrp/device_xiaomi_amethyst-recovery`** (brunch `fox_14.1`)
Fork: `shripad-jyothinath/device_xiaomi_amethyst-recovery`
Target: `device/motorola/marvel`

Why this base: **same SoC (SM7635 "volcano")**, same GKI/header-v4 layout, and — critically —
**the same partition scheme**: dynamic `super`, A/B, and a **dedicated `recovery` partition with no
kernel** (`BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`,
`BOARD_USES_RECOVERY_AS_BOOT :=` empty, `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT :=` empty).
It also has working FBE decryption on this platform.

## 9.1 The important insight from amethyst: it does **not** bundle modules

Amethyst has no `prebuilt/modules/` tree at all — its `prebuilt/` contains only `kernel` and
`dtb`. Instead it loads modules **from the vendor partition** at runtime:

```make
TW_LOAD_VENDOR_MODULES  += "panel_event_notifier.ko xiaomi_touch.ko goodix_core.ko
TW_LOAD_VENDOR_MODULES  += focaltech_touch.ko adsp_loader_dlkm.ko
TW_LOAD_VENDOR_MODULES  += qti_battery_charger.ko camera.ko stm_st54se_gpio.ko"
```

**This is the line the marvel `ofrp` tree was missing entirely.** Without
`TW_LOAD_VENDOR_MODULES`, TWRP never loads the touch/USB modules from `/vendor` — which is the
real reason touch and USB were dead. Bundling modules into the recovery ramdisk
(`BOARD_RECOVERY_KERNEL_MODULES`, what `docs/03` recommends) also works, but it is not required;
`TW_LOAD_VENDOR_MODULES` is the lighter fix and is what the proven SM7635 tree uses.

For marvel the equivalent list (from the dump, `docs/08`) is:

```make
TW_LOAD_VENDOR_MODULES += \
    "panel_event_notifier.ko mmi_annotate.ko mmi_info.ko mmi_relay.ko \
     sensors_class.ko touchscreen_mmi.ko goodix_brl_mmi.ko \
     goodix_fod_mmi.ko rbs_fod_mmi.ko mmi_stow.ko \
     qti_battery_charger.ko camera.ko adsp_loader_dlkm.ko"
```

## 9.2 File-by-file rebrand

| amethyst | marvel |
|---|---|
| `device/xiaomi/amethyst` | `device/motorola/marvel` |
| `amethyst` (all) | `marvel` |
| `xiaomi` | `motorola` |
| `fox_amethyst.mk` | `fox_marvel.mk` |
| `PRODUCT_NAME` / lunch `fox_amethyst-*` | `fox_marvel-*` |
| `TARGET_OTA_ASSERT_DEVICE := amethyst,amethyst_global` | `marvel,marvel_g,XT2605,XT2605-1..4` |
| `OF_MAINTAINER := chkndrp` | `OF_MAINTAINER := Shripad` |
| `OF_SCREEN_H := 2400` | `2712` |
| `TARGET_SCREEN_DENSITY := 480` | `440` |
| `TARGET_SCREEN_WIDTH/HEIGHT := 1220/2712` | **same** (identical panel class) |
| `BOARD_ROOT_EXTRA_SYMLINKS += /vendor/odm/firmware:/vendor/odm/firmware/p16u` | `/vendor/fsg:/fsg` |
| `TARGET_BOARD_PLATFORM_GPU := qcom-adreno810` | marvel uses **Adreno 810** too (SM7635) — verify |
| `TARGET_BOOTLOADER_BOARD_NAME := amethyst` | `marvel` |

### Partition sizes (amethyst → marvel, from `fastboot getvar`)

| partition | amethyst | **marvel (real)** |
|---|---|---|
| `recovery` | `104857600` (100 MB) | **`134217728` (128 MB)** |
| `boot` | `100663296` | `100663296` ✓ |
| `init_boot` | `8388608` | `8388608` ✓ |
| `vendor_boot` | `100663296` | `100663296` ✓ |
| `dtbo` | `20971520` | **`34603008`** |
| `super` | `9126805504` | **`21474836480`** |
| dynamic group size | `9116319744` | **`21470642176`** |
| group name | `qti_dynamic_partitions` | `mot_dp_group` |

### Dynamic partition list

amethyst: `system system_ext product vendor vendor_dlkm system_dlkm odm` (all erofs).

marvel: **no `odm` partition** — `TARGET_COPY_OUT_ODM := vendor/odm` and `odm` is absent from
`BOARD_MOT_DP_GROUP_PARTITION_LIST`. Remove `odm` from the list and from the fstab.

marvel file systems are mixed (`system`/`system_ext`/`vendor` erofs, `product`/`vendor_dlkm`/
`system_dlkm` ext4) so keep the **dual erofs+ext4 fstab lines** amethyst already uses — that part
transfers unchanged.

### Things that transfer unchanged (same platform)

- `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`, `BOARD_USES_GENERIC_KERNEL_IMAGE := true`,
  `BOARD_BOOT_HEADER_VERSION := 4`, `BOARD_RAMDISK_USE_LZ4 := true`
- `TARGET_USE_CUSTOM_LUN_FILE_PATH`
- `TARGET_RECOVERY_QCOM_RTC_FIX := true`
- `sysfs_path=/sys/devices/platform/soc/1d84000.ufshc` (confirmed for SM7635)
- `/metadata` f2fs + `wrappedkey`, `/data` `…+wrappedkey_v0, metadata_encryption=…, sysfs_path=…`
- `TW_INCLUDE_CRYPTO / _FBE / _FBE_METADATA_DECRYPT`, `BOARD_USES_QCOM_FBE_DECRYPTION`
- `TW_INCLUDE_OMAPI := true`
- the whole `init.recovery.encryption.rc` bring-up (`qseecomd → ssgtzd/keymint-qti/gatekeeper-qti
  → keymint-strongbox/weaver/secure_element`)
- the cpuset block and the UFS tuning in `init.recovery.qcom.rc`
- `OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1`, `OF_USE_AIDL_BOOT_CONTROL := 1`,
  `OF_VAB_ORS_WIPE_DATA_IS_FORMAT := 1`, `OF_USE_DMCTL := 1`
- `device.mk` TWRP block (`TW_THEME`, `TW_INCLUDE_*`, `TW_FRAMERATE`, crypto flags)

### Things that must change (vendor-specific)

| | amethyst (Xiaomi) | marvel (Motorola) |
|---|---|---|
| touch modules | `xiaomi_touch.ko`, `goodix_core.ko`, `focaltech_touch.ko` | `mmi_*`, `touchscreen_mmi.ko`, `goodix_brl_mmi.ko`, `panel_event_notifier.ko` |
| `TW_INPUT_BLACKLIST` | `"uinput-goodix"` | marvel equivalent (verify) |
| haptics sysfs | `sih_haptic_688X`, `awinic_haptic` | Motorola vibrator nodes (`/sys/class/leds/vibrator/*`) |
| boot control | `OF_USE_AIDL_BOOT_CONTROL := 1` | QTI boot HAL — **verify marvel's** |
| prebuilt kernel/dtb | Xiaomi | marvel's `prebuilt/kernel`, `prebuilt/dtb/marvel.dtb` |
| firmware blobs | `st54l_fw.bin`, Xiaomi firmware_mnt set | marvel's own |

## 9.3 Build

```sh
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp_16
repo sync
# tree at device/motorola/marvel
source build/envsetup.sh
lunch fox_marvel-eng        # or twrp_marvel-eng if rebranded to TWRP
mka recoveryimage
```

## 9.4 Order of work

1. fork + clone amethyst (done)
2. rename tree → `device/motorola/marvel`, rebrand identifiers
3. swap the prebuilt kernel / dtb / partition sizes / dynamic group
4. replace the touch module list with the marvel chain from `docs/08`
5. copy the encryption `.rc` + fstab nearly verbatim
6. drop `odm` from the dynamic partition list and fstab
7. build under `twrp_16`
