# 01 — Device tree deep analysis: `device/motorola/marvel` (branch `evox-a17`)

Read-only analysis. Nothing in the Evolution X tree was modified for this document.

## 1. Inventory

```
Android.bp / Android.mk          Soong namespace + no-op all-makefiles-under guard
AndroidProducts.mk               evolution_marvel / lineage_marvel lunch choices
BoardConfig.mk                   236 lines — board, partitions, AVB, recovery
common.mk                        481 lines — the bulk of the product config
device.mk                        62 lines  — screen, RROs, camera, vendor inherit
evolution_marvel.mk / lineage_marvel.mk
odm.prop / product.prop / system.prop / system_ext.prop / vendor.prop
rootdir/etc/fstab.qcom           hand-written fstab (diverges from stock)
rootdir/etc/init.marvel.rc       panel/touch/fp/charger sysfs perms
rootdir/bin/init.mmi.touch.sh
rootdir/linkerconfig/ld.config.txt
init/init.qcom.recovery.rc       recovery init (was NOT copied into the ramdisk)
modules.load / .vendor_boot / .recovery / .system_dlkm
modules.blocklist / modules.systemdlkm_blocklist
modules/vendor_dlkm/*.ko         292 prebuilt modules
modules/vendor_boot/*.ko         294 prebuilt modules
prebuilt/kernel                  35.6 MB GKI Image (6.1.157-android14-11)
prebuilt/kernel-headers.tar.gz
prebuilt/dtb/marvel.dtb          "Qualcomm Technologies, Inc. Volcano SoC"
prebuilt/dtb.img / sm7750.dtb    (duplicate dtb, unused)
prebuilt/dtbo.img                34,603,008 bytes
patches/                         4 ROM patches + apply_patches.sh
proprietary-files.txt            126 KB blob list
rro_overlays/                    MarvelFrameworksOverlay, MarvelSystemUIOverlay
seccomp_policy/mediacodec-arm64-additions.policy
sepolicy/vendor/                 file.te, file_contexts, service_contexts, 3 .te files
shims/qti_perfd_client_system.cpp
udfps-hbm/                       RoadSTR-derived UDFPS HBM daemon
vintf/manifest.xml               stale duplicate (target-level 7)
vintf/vintf/*.xml                the files actually used
```

## 2. `BoardConfig.mk`

### Correct
- `TARGET_BOARD_PLATFORM := volcano` — matches the DTB ("Volcano SoC").
- `TARGET_ARCH_VARIANT := armv8-2a-dotprod` — valid in this Soong
  (`build/soong/cc/config/arm64_device.go:40`).
- `BOARD_USES_GENERIC_KERNEL_IMAGE := true`, `BOARD_BOOT_HEADER_VERSION := 4`,
  `BOARD_INIT_BOOT_HEADER_VERSION := 4`, `BOARD_RAMDISK_USE_LZ4 := true`.
- `TARGET_KERNEL_VERSION := 6.1` matches the prebuilt kernel
  (`6.1.157-android14-11-gc7dd3fa941b3-ab15371444`).
- Partition sizes: boot/vendor_boot `100663296`, init_boot `8388608`, recovery `134217728`
  — all match the on-device values read via `fastboot getvar partition-size:*`.
- `BOARD_MOT_DP_GROUP_PARTITION_LIST := product system system_ext vendor vendor_dlkm system_dlkm`
  with `TARGET_COPY_OUT_ODM := vendor/odm` → **no `odm` partition exists**.

### Wrong / risky
| Line | Problem |
|---|---|
| `TARGET_CPU_VARIANT_RUNTIME := oryon` | `oryon` is an SM8750/Oryon value. `grep -rn oryon build/soong/cc/config/` → nothing, so it is silently ignored. marvel is Kryo. |
| `BOARD_DTBOIMG_PARTITION_SIZE := 37748736` | Real partition is `0x02100000 = 34603008`. `dtbo.img` is built larger than the partition → `fastboot flash dtbo` fails. |
| `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` | Removed by `9287111`, restored later. marvel's ABL needs the recovery image **kernel-less**. |
| `BOARD_BOOTCONFIG += androidboot.roadstr_init_probe=trace_actions` | roadstr leftover. |
| `BOARD_AVB_VBMETA_SYSTEM_*` test keys | fine for unofficial, but the rollback index must stay ≥ the device floor (`BOARD_AVB_ROLLBACK_INDEX := 1`). |
| `TARGET_SCREEN_DENSITY := 440` | panel is `boe_nt37713_678_1272x2772...` → real resolution 1272×2772, tree says 1220×2712. |

## 3. `common.mk`

It is a near-copy of `sm7750-common/common.mk` (which is really the renamed `sun-common`,
i.e. **SM8750** — see `soytony/…roadstr` commit *"Rename sun-common to sm7750-common"*).

Missing vs the reference:
- `telephony-ext` in `PRODUCT_PACKAGES` **and** `PRODUCT_BOOT_JARS += telephony-ext`
- `vendor.gatekeeper.is_security_level_spu=0` in the ART/heap `PRODUCT_VENDOR_PROPERTIES`
- the common resource overlays (`FrameworksResCommon`, `LineageSdkCommon`, `SystemUIResCommon`,
  `TelephonyResCommon`, `WifiResCommon`)
- `PRODUCT_PRIVATE_SEPOLICY_DIRS` / `PRODUCT_PUBLIC_SEPOLICY_DIRS`

Present but questionable:
- `PRODUCT_SHIPPING_API_LEVEL := 34` — stock marvel shipped **Android 16 → 36**. Setting 34 is a
  VINTF workaround and produces `ro.product.first_api_level=32` (via Lineage's
  `SPOOF_FIRST_API_LEVEL_32`).
- `DEVICE_MANIFEST_FILE := $(LOCAL_PATH)/vintf/vintf/manifest.xml` — a nested `vintf/vintf/`
  directory; there is also a stale `vintf/manifest.xml` (target-level 7) that is unused.
- `$(TARGET_COPY_OUT_ROOT)/linkerconfig/ld.config.txt` — valid (`TARGET_COPY_OUT_ROOT := root`).

## 4. `fstab.qcom` (hand-written)

Diverges from the stock-derived reference in ways that break recovery mounting:

| entry | tree | stock-derived reference | effect |
|---|---|---|---|
| `odm` | active logical mount | **commented out** | no `odm` partition exists → mount error |
| `/metadata` | `ext4` | **`f2fs`** | metadata holds the key dir; wrong type → `/data` cannot decrypt |
| `/data` | no `wrappedkey_v0`, no `metadata_encryption`, no `sysfs_path` | `…+wrappedkey_v0`, `metadata_encryption=aes-256-xts:wrappedkey_v0`, `sysfs_path=…ufshc` | FBE v2 wrapped-key data cannot be decrypted |
| `modem` | `vfat` | `ext4` | firmware mount failure |
| logical partitions | one fs type each | **both `erofs` and `ext4`** | recovery cannot mount an OS whose fs type differs from the build choice |
| missing | `/boot`, `/init_boot`, `/vendor_boot`, `/dtbo`, `/recovery`, `logks`, `prodpersist`, `spunvm`, `fsg`, `bt_firmware` | present | OTA / fastbootd / recovery flashing paths incomplete |

## 5. Kernel modules

- `modules.load.recovery` — 301 entries, correct **volcano** list
  (`pinctrl-volcano`, `gcc-volcano`, `qnoc-volcano`, `dispcc-volcano`, `msm_drm`, `dwc3-msm`, …).
- `modules.load.vendor_boot` — 294 entries, volcano.
- `modules.blocklist` **deliberately blocks** `goodix_brl_mmi`, `goodix_fod_mmi`, `rbs_fod_mmi`
  (Motorola loads the right touch driver on demand) → recovery must force-load them.
- `modules.load.system_dlkm` is **empty** and `BOARD_SYSTEM_KERNEL_MODULES` is never set.

`BoardConfig.mk` (before `ae2627c`) set only the `_LOAD` variables, never
`BOARD_VENDOR_KERNEL_MODULES` / `BOARD_VENDOR_RAMDISK_KERNEL_MODULES` →
see `03-root-cause.md`.

## 6. VINTF

- `vintf/vintf/manifest.xml` — `target-level="8"`, `version="8.0"`. It declared
  `android.hardware.graphics.composer` **v1**, but the vendor serves
  `android.hardware.graphics.composer3` v2 (`vendor.qti.hardware.display.composer-service`).
  **Fixed in `ae2627c`.**
- `vintf/vintf/vendor_framework_compatibility_matrix.xml` — `version="9.0"` while the device
  manifest targets level 8. Mixing FCM 9 framework matrix with a level-8 device manifest is
  inconsistent.
- `vintf/manifest.xml` (the non-nested one) is dead weight.

## 7. `patches/`

Four patches applied by `apply_patches.sh`, which `build_evox.sh` calls before building:
1. `hardware/lineage/interfaces` — UDFPS HBM service
2. `frameworks/base` — SystemUI optional UDFPS HBM
3. `bionic` — `PROP_VALUE_MAX` / system properties
4. `vendor/lineage` — extract `TARGET_PREBUILT_KERNEL_HEADERS` in `generated_kernel_includes`

Patch 4 matters: without it Soong fails with
`unknown variable '$(KERNEL_BUILD_OUT_PREFIX)'`. Note `build/make/core/config.mk` only includes
`vendor/lineage/config/BoardConfigLineage.mk` when `LINEAGE_BUILD` is non-empty, and
`vendor/lineage/build/envsetup.sh` only sets it for `lineage_*` products — so
`lunch evolution_marvel-*` is a **dead path**; use `lunch lineage_marvel-userdebug`.

## 8. sepolicy

Very thin: one data type, three `file_contexts` lines, one `service_contexts` line, three `.te`
files. No `genfs_contexts`, no property contexts. The `udfps-hbm` service relies on
`hal_fingerprint_default_exec` and a custom `udfps_hbm_service` type.

## 9. Summary of device-tree findings

| severity | finding |
|---|---|
| blocker | recovery ramdisk got **0 kernel modules** (no `BOARD_*_KERNEL_MODULES`) |
| blocker | `init/init.qcom.recovery.rc` never copied into the recovery ramdisk |
| high | `fstab.qcom` wrong (`odm`, metadata fs, modem fs, wrapped-key, single fs type) |
| high | `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` removed then restored |
| high | `dtbo` partition size 37748736 > real 34603008 |
| medium | `PRODUCT_SHIPPING_API_LEVEL := 34` (stock is 36) |
| medium | VINTF composer HAL wrong (fixed) / FCM 9 vs target-level 8 |
| medium | `TARGET_CPU_VARIANT_RUNTIME := oryon` (SM8750 value, ignored) |
| medium | roadstr leftovers (`androidboot.roadstr_init_probe`, `sun` prop comments) |
| low | screen size 1220×2712 vs real 1272×2772 |
| low | `vintf/manifest.xml` stale duplicate |
| low | `telephony-ext`, gatekeeper SPU prop, common RROs missing |
