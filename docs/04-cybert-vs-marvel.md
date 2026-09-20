# 04 — cybert vs marvel: the vendor_boot-recovery trap

This is the single most important structural difference and it is **not** about MediaTek vs
Qualcomm. It is why "just copy the working cybert tree" cannot work.

## cybert's recovery lives in `vendor_boot`

`cybert_twrp/BoardConfig.mk`:

```make
115: TW_HAS_NO_RECOVERY_PARTITION := true
118: TW_INCLUDE_FASTBOOTD := true
128: BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
129: BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
```

and its README:

```sh
fastboot flash vendor_boot_a vendor_boot.img
```

So on cybert the **recovery ramdisk and every kernel module ride inside `vendor_boot`**. The
bootloader always loads the vendor ramdisk, so `touchscreen_u_mmi`, `goodix_brl_u_mmi`, the USB
gadget modules etc. are simply *there*. That is why cybert's touch and everything else works.

## marvel's recovery is a standalone partition image

| | cybert (MT6897) | **marvel (SM7635)** |
|---|---|---|
| recovery location | `vendor_boot` | **dedicated `recovery` partition (128 MB)** |
| recovery image | vendor ramdisk (with modules) | **ramdisk-only**, `kernel_size = 0` |
| kernel for recovery | prebuilt kernel in `vendor_boot` | taken from `boot` by ABL |
| `vendor_boot` loaded during recovery | **yes** | **no** |
| where recovery modules must live | vendor ramdisk | **the recovery ramdisk itself** |
| `TW_HAS_NO_RECOVERY_PARTITION` | `true` | must **not** be set |
| `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` | n/a | `true` |

Because marvel's recovery boots **standalone**, its ramdisk must be **self-contained** — and the
old tree put **0 `.ko` files** in it (`docs/03-root-cause.md`).

## What this means practically

```make
# marvel only - required because vendor_boot is NOT loaded in recovery
BOARD_RECOVERY_KERNEL_MODULES      := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
```

> **Do not set `TW_HAS_NO_RECOVERY_PARTITION` on marvel.** TWRP treats the variable as
> *defined = true*, so even `TW_HAS_NO_RECOVERY_PARTITION := false` makes TWRP believe there is
> no recovery partition. (I made exactly this mistake in the first draft — see
> `docs/06-self-review.md`.)

## cybert → marvel mapping

| cybert (MT6897, working) | marvel (SM7635) |
|---|---|
| `prebuilt/modules/vendor/*.ko` | `modules/vendor_dlkm/*.ko` |
| `prebuilt/modules/vendor_ramdisk/*.ko` | `modules/vendor_boot/*.ko` |
| `RECOVERY_KERNEL_MODULES := mmi_info mmi_relay sensors_class touchscreen_u_mmi focaltech_touch_v3_u_mmi goodix_brl_u_mmi` | `mmi_info mmi_relay mmi_annotate sensors_class touchscreen_mmi goodix_brl_mmi goodix_fod_mmi rbs_fod_mmi` |
| `BOARD_VENDOR_RAMDISK_KERNEL_MODULES += $(addprefix …/prebuilt/modules/vendor/,…)` | `BOARD_RECOVERY_KERNEL_MODULES := $(BOARD_VENDOR_KERNEL_MODULES)` |
| `TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI` | **same** |
| `TW_LOAD_VENDOR_BOOT_MODULES` | **same** |
| `TW_LOAD_VENDOR_MODULES` | **same** |
| force-load because `modules.blocklist` blocks the chip driver | **same** |
| recovery in `vendor_boot` | **dedicated recovery partition** → bundle in the ramdisk |
| `init.recovery.mt6897.rc` + MTK configfs USB (`musb_hdrc`, `11201000.usb0`) | Qualcomm `init.recovery.qcom.rc` (`a600000.dwc3`, `1d84000.ufshc`) + TWRP's default qcom USB init |
| `tee.rc` / `trustonic.rc` / MobiCore / `tzapp` / `.drbin` | **not applicable** — QTI QSEE keymint + NXP/Thales StrongBox |
| `mtk_plpath_utils`, MTK `bootctrl`, `mtk_swpm*`, `mtk_disp_notify` | QTI `bootctrl`/`gpt-utils`, no MTK power drivers |
| `TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness` | `/sys/class/backlight/panel0-backlight/brightness` |
| `TW_MAX_BRIGHTNESS := 16180` | `2047` |
| `TW_INPUT_BLACKLIST := "hbtp_vm"` (MTK touch node) | `"goodix_brl_mmi\|hbtp_vm"` |
| `TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888` | `RGBX_8888` |
| `BOARD_KERNEL_BASE := 0x40000000`, `Image.gz`, `bootopt=64S3,32N2,64N2` | `0x00000000`, `Image`, Qualcomm cmdline |
| `BOARD_SUPER_PARTITION_GROUPS := motorola_dynamic_partitions` | `mot_dp_group` |

## Alternative considered (rejected)

Switch marvel to cybert's model: recovery in `vendor_boot`,
`TW_HAS_NO_RECOVERY_PARTITION := true`, flash `vendor_boot`.

Rejected because marvel's bootloader has a dedicated **"Recovery mode"** entry that points at the
`recovery` partition. Flashing `vendor_boot` would not change what the bootloader boots in
recovery mode. Keeping the dedicated partition and making its ramdisk self-contained is the
correct path.
