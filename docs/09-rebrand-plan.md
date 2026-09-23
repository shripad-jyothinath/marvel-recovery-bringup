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

## 9.5 What the full read of amethyst changed

### (a) amethyst is a **TWRP product with OrangeFox specifics layered on**

```
AndroidProducts.mk   PRODUCT_MAKEFILES := twrp_amethyst.mk
                     COMMON_LUNCH_CHOICES := twrp_amethyst-ap2a-eng

twrp_amethyst.mk
  core_64_bit_only.mk
  base.mk
  device/xiaomi/amethyst/device.mk
  vendor/twrp/config/common.mk
  device/xiaomi/amethyst/fox_amethyst.mk      <- OFRP specifics
  PRODUCT_NAME := twrp_$(PRODUCT_DEVICE)
```

Build: `lunch twrp_amethyst-ap2a-eng && mka adbd recoveryimage`
`board-info.txt`: `require board=amethyst|volcano`

So the rebrand is **`twrp_marvel.mk` + `fox_marvel.mk`**, lunch `twrp_marvel-<release>-eng`,
`board-info.txt` → `require board=marvel|volcano`.

### (b) amethyst's crypto services are **Thales**, marvel needs **NXP**

`recovery/root/vendor/etc/init/` in amethyst contains:

```
android.hardware.security.keymint-service.strongbox-thales.rc
    service vendor.keymint-strongbox /vendor/bin/hw/android.hardware.security.keymint-service.strongbox-thales
        interface aidl android.hardware.security.sharedsecret.ISharedSecret/strongbox
        user root; group root system wakelock
        setenv LD_LIBRARY_PATH /vendor/lib64:/vendor/lib64/hw:/system/lib64:/bin
        seclabel u:r:recovery:s0
        task_profiles CPUSET_SP_FOREGROUND

android.hardware.weaver-service.thales.rc
    service vendor.weaver /vendor/bin/hw/android.hardware.weaver-service.thales
        user root; group root drmrpc

qseecomd.rc
    service vendor.qseecomd /vendor/bin/qseecomd
        socket notify-topology stream 660 system drmrpc
```

marvel's `config.fs` ships **both** families:

```
keymint-service.strongbox-nxp   / weaver-service.nxp   / authsecret-service.nxp-qti
keymint-service.strongbox-thales / weaver-service.thales / authsecret-service.thales-qti
```

Since the user identifies marvel's stack as **`weaver (nxp) + secure_element + keymint`**, the
rebrand must use the **NXP** service binaries:

```sh
service vendor.keymint-strongbox /vendor/bin/hw/android.hardware.security.keymint-service.strongbox-nxp
service vendor.weaver            /vendor/bin/hw/android.hardware.weaver-service.nxp
service vendor.authsecret        /vendor/bin/hw/android.hardware.authsecret-service.nxp-qti
service vendor.secure_element    /vendor/bin/hw/android.hardware.secure_element-service.qti
```

`vendor.keymint-qti`, `vendor.gatekeeper-qti`, `vendor.ssgtzd`, `vendor.qseecomd` are unchanged.

### (c) amethyst's `vintf/manifest.xml` (recovery, device side)

```xml
<manifest version="7.0" type="device" target-level="8">
    android.hidl.manager@1.2 IServiceManager/default
    android.hidl.token@1.0 ITokenManager/default
    android.hardware.gatekeeper  IGatekeeper/default
    android.hardware.secure_element ISecureElement/eSE1
</manifest>
```

### (d) ueventd chain

`recovery/root/system/etc/ueventd.rc` imports `vendor/etc/ueventd.rc` **and**
`vendor/odm/etc/ueventd.rc`. All three files must be carried over (they contain the QTI device
node permissions + `firmware_directories /vendor/firmware/ /vendor/firmware_mnt/image` + the
`external_firmware_handler` entries for `trustedvm`/`oemvm` — loader paths will differ per device).

### (e) helper scripts worth porting

| script | purpose | marvel delta |
|---|---|---|
| `system/bin/pre_rom_flash.sh` | SPL-date spoof, CPU governor → performance, UFS `auto_hibern8`/`clkgate`/`wb_buf_flush` off, back up OrangeFox to `/tmp/fox_backup.img` | UFS address already correct (`1d84000`) |
| `system/bin/post_rom_flash_completion.sh` | undo the above | unchanged |
| `system/bin/runatboot.sh` | wait for `qcom-battery`, force-start `touchfeature-service` | Xiaomi-only → replace with the marvel MMI touch probe |
| `system/bin/virtual_torch.sh` + `etc/init/virtual_torch.rc` | flashlight workaround (`led:torch_0`, `led:switch_0`) | only if marvel exposes the same LED nodes |
| `github/workflows/mirror.yml` | GitLab sync (needs secrets) | optional |

## 9.6 Corrected rebrand checklist

1. `device/xiaomi/amethyst` → `device/motorola/marvel`
2. `twrp_amethyst.mk` → `twrp_marvel.mk` (`PRODUCT_BRAND := motorola`, `PRODUCT_MODEL := motorola edge 70 fusion`, `PRODUCT_MANUFACTURER := motorola`)
3. `fox_amethyst.mk` → `fox_marvel.mk` (`OF_MAINTAINER := Shripad`, `OF_SCREEN_H := 2712`)
4. `AndroidProducts.mk` → `twrp_marvel.mk`, lunch `twrp_marvel-<release>-eng`
5. `board-info.txt` → `require board=marvel|volcano`
6. `BoardConfig.mk` → partition sizes / group name / dtbo size (table in §9.2), drop `odm` from the dynamic list
7. `device.mk` → replace `TW_LOAD_VENDOR_MODULES` with the marvel touch chain (drop `xiaomi_touch.ko`, `goodix_core.ko`, `focaltech_touch.ko`, `stm_st54se_gpio.ko`), keep the crypto flags, add `TW_INCLUDE_OMAPI := true`
8. `recovery.fstab` → drop `odm`, keep dual erofs/ext4, keep wrappedkey on `/metadata` and `/data`
9. `twrp.flags` → swap `rescue`/`logfs`/Xiaomi names for marvel's partitions
10. crypto `.rc` → **NXP** strongbox/weaver/authsecret + `secure_element` + `qseecomd` + `ssgtzd` + `keymint-qti` + `gatekeeper-qti`
11. `runatboot.sh` → marvel MMI touch probe instead of `touchfeature-service`
12. prebuilts → marvel's `kernel`, `dtb`, firmware blobs

