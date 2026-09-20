# Marvel (Motorola Edge 70 Fusion) — OFRP device tree: deep analysis & rewrite

Target: `device/motorola/marvel` on branch **`ofrp`** (OrangeFox R12.1 / TWRP-based).
Reference: `cybert` (Moto Edge 60 Pro, MT6897) + official TeamWin trees.

---

## 1. Symptoms

Your OFRP build **boots** (display works, TWRP UI + running clock), but:

- touch does nothing
- volume keys do nothing
- no USB at all — no adb, no MTP, no fastbootd, Windows never even enumerates the device

## 2. Root cause — the recovery image contains **zero kernel modules** and nothing loads them

The `ofrp` BoardConfig sets only the *load-list* variables and never the *module* variables:

```make
BOARD_VENDOR_KERNEL_MODULES_LOAD          := $(shell cat modules.load)              # list of names
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD  := $(shell cat modules.load.vendor_boot)  # list of names
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(shell cat modules.load.recovery)
```

…but **never**:

```make
BOARD_VENDOR_KERNEL_MODULES        := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)
BOARD_RECOVERY_KERNEL_MODULES      := ...
```

and the `ofrp` branch has **no `modules/` directory at all**.

`build/make/core/Makefile` only copies modules when `BOARD_<X>_KERNEL_MODULES` is non-empty
(`build-image-kernel-modules-dir` returns nothing otherwise). So:

- `out/target/product/marvel/recovery/root` → **0 `.ko` files** (verified earlier: `ko count: 0`)
- the vendor ramdisk has nothing to load
- TWRP is never told to load modules from `/vendor`

Result: no `touchscreen_mmi` / `goodix_brl_mmi` (touch), no `dwc3-msm` + `usb_f_*` (USB gadget → no adb/MTP),
no input driver for the volume keys. Display survived because the panel/DRM path is brought up early by
the prebuilt kernel + vendor ramdisk, which is why the UI appears while everything else is dead.

### Secondary: the module lists are **roadstr (SM8750 / "sun") lists**, not marvel (volcano)

`ofrp:modules.load.recovery` is 305 lines of `*_sun.ko`, `*_tuna.ko`, `*_kera.ko`, `*_niobe.ko`,
`qnoc-sun.ko`, `gcc-sun.ko`, `videocc-sun.ko` … — none of those exist on volcano/SM7635.
The correct list is the one on your `evox-a17` branch (`pinctrl-volcano`, `gcc-volcano`,
`qnoc-volcano`, `dispcc-volcano`, `msm_drm`, `dwc3-msm`, …).

### Tertiary

- `TARGET_CPU_VARIANT_RUNTIME := oryon` — an SM8750/Oryon value; `oryon` isn't even recognised by
  this Soong (`grep oryon build/soong/cc/config/` → nothing), so it silently does nothing. Remove it.
- `BOARD_BOOTCONFIG` still contains `androidboot.roadstr_init_probe=trace_actions` — roadstr leftover.
- `TW_INPUT_BLACKLIST := "hbtp_vm"` — `hbtp_vm` is a **MediaTek** touch device (from the cybert tree).
  On marvel it blacklists the wrong thing.
- `recovery/touch_probe.sh` probes `focaltech_v3_4`, `novatek_touch`, `synaptics_tcm2` — irrelevant on
  marvel; and it never loads `mmi_info`/`mmi_relay`/`sensors_class`, which the MMI touch stack needs.
- `modules.blocklist` (evox) deliberately blocks `goodix_brl_mmi`, `goodix_fod_mmi`, `rbs_fod_mmi`,
  so they are **never** auto-loaded — recovery must load them explicitly.

## 2b. Why cybert works but marvel didn't (the vendor_boot vs recovery-partition trap)

cybert's recovery is a **vendor_boot recovery** — `TW_HAS_NO_RECOVERY_PARTITION := true`,
`BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true`,
`BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true`, and its README flashes
`fastboot flash vendor_boot_a vendor_boot.img`. Its recovery ramdisk *and every kernel module*
ride inside `vendor_boot`, which the bootloader always loads. That is why touch/USB "just work".

marvel is the opposite: it has a **dedicated 128 MB `recovery` partition** and a **ramdisk-only**
recovery image (kernel comes from `boot`). `vendor_boot` is **not** loaded during recovery, so
the recovery ramdisk must be **self-contained** — and the old tree shipped **0 `.ko` files** in it.

| | cybert | marvel |
|---|---|---|
| recovery location | `vendor_boot` | dedicated `recovery` partition |
| recovery image | vendor ramdisk (+ modules) | ramdisk-only, no kernel |
| `vendor_boot` loaded in recovery | yes | **no** |
| where recovery modules must live | vendor ramdisk | **the recovery ramdisk** |

So copying cybert 1:1 cannot work; the modules have to be packaged explicitly
(`BOARD_RECOVERY_KERNEL_MODULES`, see §4). **Never set `TW_HAS_NO_RECOVERY_PARTITION` on
marvel** — TWRP treats it as *defined = true*, so even `:= false` makes TWRP think there is no
recovery partition.

## 3. What marvel actually needs

From the stock vendor module set (`device/motorola/marvel/modules/vendor_dlkm`, 292 modules):

| Purpose | Modules |
|---|---|
| Touch core (MMI) | `touchscreen_mmi.ko` |
| Touch chip (Goodix BRL — marvel's panel) | `goodix_brl_mmi.ko` |
| Touch/FOD extras | `goodix_fod_mmi.ko`, `rbs_fod_mmi.ko` |
| MMI glue | `mmi_info.ko`, `mmi_relay.ko`, `mmi_annotate.ko` |
| Input / sensors | `sensors_class.ko` |
| Display | `msm_drm.ko`, `drm_display_helper.ko`, `panel_event_notifier.ko` |
| USB device (adb/MTP) | `dwc3-msm.ko`, `usb_f_cdev.ko`, `usb_f_gsi.ko`, `usb_f_ccid.ko`, `usb_f_qdss.ko` |
| USB PHY / redriver | `phy-msm-ssusb-qmp.ko`, `phy-msm-snps-eusb2.ko`, `repeater-qti-pmic-eusb2.ko`, `wcd_usbss_i2c.ko` |

Note `goodix_brl_mmi` / `goodix_fod_mmi` are in `modules.blocklist`, so they must be force-loaded.

## 4. Fixes applied in this rewrite

1. **Package modules** — `BOARD_VENDOR_KERNEL_MODULES`, `BOARD_VENDOR_RAMDISK_KERNEL_MODULES`, and
   `BOARD_RECOVERY_KERNEL_MODULES` so recovery is self-contained.
2. **Load lists replaced with the volcano lists** (copied from `evox-a17`).
3. **TWRP module loading** — `TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI`, `TW_LOAD_VENDOR_BOOT_MODULES`,
   `TW_LOAD_VENDOR_MODULES`.
4. **New `init.recovery.qcom.rc`** — explicit touch module probe + correct Qualcomm USB configfs
   (with the "nuke then relink" pattern proven in the official `a16xm` tree, which fixes USB
   enumeration failures).
5. **`touch_probe.sh` rewritten** for marvel (Goodix BRL + MMI glue, force-loaded).
6. Removed roadstr/oryon/`hbtp_vm` leftovers.
7. UI/config improvements from the official references (`TW_FRAMERATE`, `TW_SCREEN_BLANK_ON_BOOT`,
   `RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH`, `TW_MTP_DEVICE`, `TW_USE_TOOLBOX`, …).

## 5. Encryption framework (answered)

**Keymint + Trustonic (MobiCore / t-base)**, *not* Thales/StrongBox.

Evidence (from the cybert MT6897 tree, same Motorola/MTK vendor stack, and consistent with marvel's
`vendor.prop` `ro.vendor.keymaster.nonsecure_algorithm=gatekeeper` / `ro.hardware.keystore_desede=true`):

- `system.prop`: `ro.hardware.gatekeeper=trustonic`, `ro.hardware.kmsetkey=trustonic`,
  `ro.vendor.mtk_trustonic_tee_support=1`, `ro.vendor.mtk_tee_gp_support=1`
- services: `android.hardware.security.keymint@3.0-service.trustonic`,
  `android.hardware.gatekeeper-service.trustonic`, `vendor.trustonic.tee@1.1-service`,
  `vendor.trustonic.tee.tui@1.0`, `mcDriverDaemon`
- `libteeservice_client.trustonic.so`, `libMcClient.so`, `libTEECommon.so`, `libTEECommon.so`
- MobiCore t-Drv trustlets (`*.drbin`) in `/vendor/app/mcRegistry`, plus `t-base-tui.ko`,
  `mcDrvModule-ffa.ko`, `isee-ffa.ko`
- `tzapp` partition holds the trustlets (`.drbin`/`.tlbin`)

StrongBox/OMAPI was evaluated by the cybert author and **dropped** — the working decryption path is
Trustonic + `tzapp`.

> For marvel specifically: it is Qualcomm SM7635 (volcano), and its `vendor.prop` says
> `ro.vendor.keymaster.nonsecure_algorithm=gatekeeper` — the QTI equivalent is the **QSEE/TEE
> keymaster + gatekeeper** (`qseecom_proxy`, `tz_log_dlkm`), i.e. no MobiCore. The `cybert`/Trustonic
> pattern applies to the MediaTek side; do **not** copy the MobiCore `tee.rc`/`trustonic.rc` into
> marvel. For marvel the crypto work is the QTI side (`TW_INCLUDE_CRYPTO_FBE`,
> `BOARD_USES_QCOM_FBE_DECRYPTION`, `TW_USE_FSCRYPT_POLICY := 2`) which the tree already sets.

## 6. Touch modules (answered)

marvel = **Goodix BRL** optical UDFPS panel family:
`touchscreen_mmi.ko` + `goodix_brl_mmi.ko` (+ `goodix_fod_mmi.ko`, `rbs_fod_mmi.ko`) with
`mmi_info.ko`, `mmi_relay.ko`, `mmi_annotate.ko`, `sensors_class.ko`.
All three touch chips in the Motorola MT6897 family are covered in the reference tree
(Focaltech `focaltech_touch_v3_u_mmi`, Goodix `goodix_brl_u_mmi`, ChipOne `cps4038_mmi`) — marvel only
needs the Goodix one, which is why commit `e7b6d46` removed `focaltech_v3_4.ko`.

## 6b. Encryption framework — SM7635 vs MT6897 (both answered)

Two different answers depending on the SoC, and this matters:

| Platform | Device | Keymaster/Keymint | StrongBox / Weaver | TEE |
|---|---|---|---|---|
| **MT6897** (MediaTek) | Moto Edge 60 Pro (cybert) | `android.hardware.security.keymint@3.0-service.trustonic` | — | **Trustonic / MobiCore** (`mcDriverDaemon`, `vendor.trustonic.tee@1.1`, `tzapp`, `.drbin`) |
| **SM7635** (Qualcomm) | Redmi Note 14 Pro+ (amethyst) | `android.hardware.security.keymint-service-qti` | **Thales StrongBox + Weaver + SPU** (`strongbox-thales`, `weaver-service.thales`, `libspukeymint*`, `libjc_keymint-thales`) | QTI / QSEE (`qseecomd`, `ssgtzd`) |
| **SM7635** (Qualcomm) | **marvel** | QTI keymint (`ro.vendor.keymaster.nonsecure_algorithm=gatekeeper`) | present only if the SKU ships an SPU | QTI / QSEE |

**So:**
- The **cybert** question ("Trustonic vs Thales") → **Trustonic**.
- The **marvel** question → it is **not** MobiCore/Trustonic at all. marvel is Qualcomm SM7635; its crypto is
  the **QTI keymint/gatekeeper stack**, and if the SKU has StrongBox it is **Thales** (same as amethyst).
  Do **not** port the `tee.rc` / `trustonic.rc` / `tzapp` machinery from the MTK reference into marvel.

For recovery, what actually matters on marvel is already in the tree:
`TW_INCLUDE_CRYPTO_FBE`, `TW_INCLUDE_FBE_METADATA_DECRYPT`, `BOARD_USES_QCOM_FBE_DECRYPTION`,
`TW_USE_FSCRYPT_POLICY := 2`, plus `ro.crypto.volume.filenames_mode=aes-256-cts` (added in `system.prop`).

## 6c. "Gold" commits mined from matching trees

### `chkndrp/device_xiaomi_amethyst-recovery` — **same SoC (SM7635/volcano), OFRP**
- `BoardConfig.mk: explicitly set TARGET_USE_CUSTOM_LUN_FILE_PATH to prevent issues`
- `init: symlink bootdevice earlier`
- `init: setup cpuset to make task_profiles work` / `init: append task_profiles to services`
- `recovery.fstab: replace fsync=nobarrier with fsync=posix`
- `init: do more waiting for stability` / `init: do filesystem tuning earlier`
- `init: add a catch to the twrp.modules.loaded block to prevent re-execution`
- `init: stop forcing the legacy sysfs fallback`
- `twrp.flags: add/adjust even more partitions`
- `prebuilt: remove all kernel module prebuilts` (load from vendor instead of ramdisk)
- `vendorsetup.sh: bundle magisk into the ramdisk`

### `TeamWin/android_device_samsung_a16xm` — MT6835, most modern official
- `init: Load DLKM modules separately to avoid issues when the user has a custom kernel that breaks the ABI.`
- `init: symlink the block devices to /dev/block/by-name and /dev/block/bootdevice`
- `init: add USB OTG switcher service for automatic role switching in recovery`
- `BoardConfig: enable model name for device ID`
- `BoardConfig: Exclude APEX images to fix the mounting errors in the logs`
- `kernel-modules: exclude GKI kernel modules` / `imported modules to recovery-root/lib from the stock vendor_boot.img`
- `BoardConfig: Force the TWRP to 64-bit and drop the legacy 32-bit support`
- `BoardConfig: remove double quotes from every variable to fix build errors`
- `twrp: fix broken graphics` → `RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true`

### `soytony/android_device_motorola_roadstr` / `sm7750-common` — your upstream
- `roadstr: Rename sun-common to sm7750-common in dependencies` → **"sm7750-common" is the renamed
  "sun-common" (SM8750)**. This is why your tree is full of `sun`/`oryon`/roadstr leftovers.
- `roadstr: validate recovery build with prebuilt headers`
- `fix(touch): wake directly on double tap`, `fix(avb): set rollback index floor`
- `fix(display): expose all panel refresh modes`

### `TeamWin/android_device_xiaomi_pissarro` — MT6877 (closest official Dimensity)
- `system.prop`: `ro.crypto.volume.filenames_mode=aes-256-cts`
- `init.recovery.*.rc`: explicit `wait /dev/block/platform/soc/<ufshci>` + `symlink ... /dev/block/bootdevice`
- `twrp.flags`: explicit per-partition flags incl. `slotselect` and `flashimg=1`

## 7. How to apply

```bash
cd /serverhive/shripad/evox
git checkout ofrp        # or: git switch ofrp
# 1) take the volcano module config from evox-a17
git checkout evox-a17 -- \
    modules.load.recovery modules.load.vendor_boot modules.load modules.blocklist \
    modules.systemdlkm_blocklist modules/vendor_dlkm modules/vendor_boot
# 2) overwrite the files from this directory (marvel_ofrp_v2/)
cp -r marvel_ofrp_v2/. device/motorola/marvel/
# 3) build
source build/envsetup.sh
lunch orangefox_marvel-eng
mka recoveryimage
```

Then flash **only** the recovery partition and boot recovery via the bootloader menu.
