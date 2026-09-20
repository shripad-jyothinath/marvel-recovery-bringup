# 06 — Self-review: deep analysis of the fixes in this repo

A critical pass over my own work. Several of these are mistakes I made and then corrected; they
are kept here on purpose because the reasoning is the useful part.

## 6.1 Mistakes I made (and fixed)

### (a) `TW_HAS_NO_RECOVERY_PARTITION := false` — **wrong, would have broken recovery**

First draft of `twrp/BoardConfig.mk`:

```make
# Motorola uses a dedicated recovery partition on this device
TW_HAS_NO_RECOVERY_PARTITION := false
```

TWRP tests this variable as *defined = true* (it is consumed by `ifdef`-style logic and
`ifeq (…,true)` in places). Setting it to `false` still **defines** it, so TWRP would have
believed marvel has no recovery partition — the exact opposite of the truth. Removed, with a
comment recording why.

### (b) My first boot-image parser was broken

`bootimg_parse.py` (v1):
- assumed a page-aligned layout for header v3/v4 and read `page_size` from offset 36 — for v4 that
  field is not the page size, so it read `0` → `ZeroDivisionError`.
- searched for the ramdisk magic in the wrong window and reported
  `ramdisk magic NOT found` for images that were fine.
- checked for the AVB footer with `data[-64:-60] == b"AvbF"` — the magic is **`AVBf`**, and AVB
  footer fields are **big-endian**. It therefore reported `AVB footer: no` for images that do have
  one.

Fixed by writing `avbfooter.py` with the correct magic/endianness and by letting the AOSP
`system/tools/mkbootimg/unpack_bootimg.py` on the server do the extraction. Lesson: don't
hand-roll binary parsers when the authoritative tool is available.

### (c) I blamed the wrong thing first

I initially framed the "boots stock ROM" symptom as the kernel-in-recovery bug (which is real) and
under-weighted the modules problem. The correct model is:

- `fastboot boot` **cannot** test this recovery at all (kernel-less image → ABL refuses;
  kernel-present image → ABL does a normal boot).
- The only meaningful test is flashing the recovery partition and booting recovery mode.

### (d) I said the blobs came from roadstr — the vendor repo says otherwise

`device/motorola/marvel/proprietary-files.txt` header claims roadstr
(`W1WRS36.39-25-2-1`), but the vendor repo commit says
`Extract proprietary vendor blobs from stock firmware (W2WE36.56-98-19)` — marvel stock. Corrected
in `docs/02-vendor-tree-analysis.md`; the inconsistency itself is now a finding.

### (e) Deliverable bug: `apply.sh` copies a `device.mk` that did not exist

`ofrp/apply.sh` did `cp -v "$SRC/device.mk" "$DT/device.mk"`, but I never wrote
`ofrp/device.mk`. With `set -e` the script would abort. Fixed by actually shipping
`ofrp/device.mk`.

### (f) `TW_INPUT_BLACKLIST` is not a regex

I wrote:

```make
TW_INPUT_BLACKLIST := "goodix_brl_mmi|hbtp_vm"
```

TWRP matches this against input device names as a list of substrings — `|` is not a regex
alternation. Corrected to a plain substring list.

## 6.2 Things that are correct but have trade-offs

### (a) `BOARD_RECOVERY_KERNEL_MODULES := $(BOARD_VENDOR_KERNEL_MODULES)` packages *all* 292 modules

- **Pro:** guaranteed self-contained; no missing-dependency surprises; recovery's
  `modules.load.recovery` (301 entries) resolves fully.
- **Con:** the recovery ramdisk grows from ~18 MB to ~50 MB, and `recovery.img` from ~54 MB to
  ~85 MB. The partition is 128 MB, so it fits — but it is wasteful.
- **Alternative:** curate the list (touch + display + USB + UFS + their dependencies). Higher risk
  of a missed dependency, which is exactly the failure mode we are fixing. Kept the broad list.

### (b) `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`

Evidence: with the kernel present, ABL treats recovery.img as a normal boot image and starts the
installed OS; kernel-less, the recovery ramdisk runs. The reference `sm7750-common` tree (the same
Motorola family) also sets this. Confidence: high, but it was only ever tested through
`fastboot boot` and a single flash — it should be re-verified after the modules fix.

### (c) The fstab rewrite is conservative on purpose

I changed only what I could justify:
- listed **both** `erofs` and `ext4` for every logical partition (strictly more permissive),
- commented out the `odm` mount (there is provably no `odm` partition:
  `TARGET_COPY_OUT_ODM := vendor/odm` and `odm` is absent from
  `BOARD_MOT_DP_GROUP_PARTITION_LIST`).

I deliberately did **not** guess at `/metadata` (`ext4` vs `f2fs`), `modem` (`vfat` vs `ext4`) or
the `/data` encryption flags in the OFRP tree, because those depend on the actual stock layout and
guessing could make things worse. They are flagged, not changed. (The TWRP `recovery.fstab` does
use the stock-derived values, since that file is recovery-only.)

## 6.3 Unverified claims — flagged honestly

| claim | status |
|---|---|
| `sysfs_path=/sys/devices/platform/soc/1d84000.ufshc` | taken from the `sm7750-common` (SM8750) reference. `1d84000.ufshc` is the usual Qualcomm UFS HC address, but **marvel's actual address was never confirmed**. |
| `sys.usb.controller = a600000.dwc3` | from the tree's own `vendor.prop` (`ro.vendor.usb.controller=a600000.dwc3`) and `androidboot.usbcontroller` — **confirmed**. |
| `wait /dev/block/platform/soc/1d84000.ufshc` in `init.recovery.qcom.rc` | same caveat as the fstab `sysfs_path`. |
| `TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone0/temp` | not verified on-device. |
| dtbo partition = `34603008` | **confirmed** via `fastboot getvar partition-size:dtbo` = `0x02100000`. |
| recovery partition = `134217728`, boot/vendor_boot = `100663296`, init_boot = `8388608` | **confirmed** via `fastboot getvar`. |
| panel = 1272×2772 | **confirmed** via `fastboot getvar all` → `primary-display: boe_nt37713_678_1272x2772_dsc_vid_144hz_v1`. |

## 6.4 Unnecessary / sloppy bits to clean up

- `twrp/recovery/root/init.recovery.qcom.rc` defines a `health-hal` service that is never started
  and duplicates what TWRP already does. Harmless, but should be deleted.
- `TW_LOAD_VENDOR_MODULES` embeds two `$(wildcard ...)` expansions — that expands to a very long
  quoted string. It works, but it duplicates `BOARD_*_KERNEL_MODULES`; it could be trimmed to just
  the modules that need force-loading.
- `twrp/BoardConfig.mk` sets `PLATFORM_SECURITY_PATCH := 2099-12-31` (the standard anti-rollback
  hack) while also setting `BOARD_AVB_ROLLBACK_INDEX := 1`. These interact: the vbmeta_system
  rollback index becomes `PLATFORM_SECURITY_PATCH_TIMESTAMP`, which is enormous. If the device has
  a real rollback floor this is fine only because the bootloader is unlocked, but it is worth
  being deliberate about rather than copying blindly.
- `prebuilt/sm7750.dtb` and `prebuilt/dtb.img` in the device tree duplicate
  `prebuilt/dtb/marvel.dtb` and are unused.

## 6.5 What I would do differently next time

1. Read the **AOSP Makefile** for the mechanism (`build-image-kernel-modules-dir`) *before*
   theorising about bootloader behaviour. The one-line root cause was visible in the build rules
   from the start.
2. Extract the shipped ramdisk **first** and count `.ko` files — that is a 30-second check that
   would have short-circuited hours of speculation.
3. Establish the recovery *layout* (dedicated partition vs vendor_boot) before comparing against
   other trees. cybert looked like a perfect reference until the layout difference was noticed.
4. Never use `fastboot boot` to test a dedicated-recovery-partition recovery.
