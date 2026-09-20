# 03 — Root cause: the recovery image shipped zero kernel modules

## The symptom

OrangeFox/TWRP for marvel **booted** — display came up, the TWRP UI rendered, the clock ran — but:

- touch did nothing
- the volume keys did nothing
- **no USB at all**: no adb, no MTP, no fastbootd; Windows never even enumerated the device
  (`Get-PnpDevice` showed no phone VID/PID, `adb devices` and `fastboot devices` empty)

## The evidence

### On the built image

```
$ unpack_bootimg --boot_img recovery.img
kernel_size: 0                 <- ramdisk-only (BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true)
ramdisk size: 18627372
boot image header version: 4
```

```
$ find out/target/product/marvel/recovery/root -name '*.ko' | wc -l
0                              <- ZERO kernel modules in the recovery ramdisk
```

```
$ find out/target/product/marvel/obj/PACKAGING/depmod_recovery_stripped_intermediates -name '*.ko' | wc -l
0
$ find out/target/product/marvel/obj/PACKAGING/depmod_vendor_ramdisk_stripped_intermediates -name '*.ko' | wc -l
300                            <- the vendor ramdisk DID get modules
```

So the **vendor** ramdisk had 300 modules (`vendor_boot.img`), but the **recovery** ramdisk had 0.

### In the `ofrp` BoardConfig

```make
# Kernel Modules
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.system_dlkm 2>/dev/null))
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load 2>/dev/null))
BOARD_SYSTEM_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.systemdlkm_blocklist
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.blocklist
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.vendor_boot 2>/dev/null))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.recovery 2>/dev/null))
BOOT_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
SYSTEM_KERNEL_MODULES := $(BOARD_SYSTEM_KERNEL_MODULES_LOAD)
```

Every variable here is a **load list** (a list of module *names*). The variables that actually
carry the `.ko` **files** are missing:

```make
BOARD_VENDOR_KERNEL_MODULES        # never set
BOARD_VENDOR_RAMDISK_KERNEL_MODULES # never set
BOARD_RECOVERY_KERNEL_MODULES      # never set
```

…and the `ofrp` branch has **no `modules/` directory at all** (verified with
`git ls-tree -r --name-only github-non-los/ofrp`), so there was nothing to package even if the
variables had been set.

## Why that produces exactly these symptoms

`build/make/core/Makefile`, line ~566:

```make
define build-image-kernel-modules-dir
$(if $(strip $(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver))$(BOARD_$(1)_KERNEL_MODULES_ARCHIVE...)),\
  ... copies modules ... \
  $(2)/lib/modules/...)
```

The whole body is guarded by `BOARD_<X>_KERNEL_MODULES`. For the recovery ramdisk the call is:

```make
$(eval ALL_DEFAULT_INSTALLED_MODULES += \
  $(call build-image-kernel-modules-dir,RECOVERY,$(TARGET_RECOVERY_ROOT_OUT),,modules.load.recovery,\
        $(RECOVERY_STRIPPED_MODULE_STAGING_DIR),$(kmd)))
```

→ with `BOARD_RECOVERY_KERNEL_MODULES` unset, **nothing is staged** into `TARGET_RECOVERY_ROOT_OUT`.

Missing module → missing functionality:

| module(s) | provides | symptom |
|---|---|---|
| `touchscreen_mmi.ko` | MMI touch core | no touch |
| `goodix_brl_mmi.ko` | Goodix BRL controller (marvel's panel) | no touch |
| `mmi_info.ko`, `mmi_relay.ko`, `mmi_annotate.ko` | MMI glue the touch driver depends on | touch probe fails |
| `sensors_class.ko` | input/sensor class | input devices missing |
| `dwc3-msm.ko` | Qualcomm USB3 device controller | **no USB gadget at all** |
| `usb_f_cdev/gsi/ccid/qdss.ko` | USB function drivers | no adb / MTP / fastbootd |
| `phy-msm-ssusb-qmp.ko`, `phy-msm-snps-eusb2.ko` | USB PHY | controller never comes up |
| `msm_drm.ko`, `drm_display_helper.ko` | display | *came up anyway* → why the UI appeared |

Display worked because the panel/DRM path is brought up early enough (and the prebuilt kernel +
stock vendor ramdisk cover it), which is exactly why the recovery looked "half working" — UI on,
everything else dead.

## Two compounding bugs

### (a) The module lists were roadstr/SM8750 lists, not volcano

`ofrp:modules.load.recovery` is 305 lines of `*_sun.ko`, `*_tuna.ko`, `*_kera.ko`,
`*_niobe.ko`, `qnoc-sun.ko`, `gcc-sun.ko`, `videocc-sun.ko`, `pinctrl-tuna.ko`, … — none of
those exist on SM7635 "volcano". The correct list is the one on `evox-a17`
(`pinctrl-volcano`, `gcc-volcano`, `qnoc-volcano`, `dispcc-volcano`, `msm_drm`, `dwc3-msm`, …).

Root of that: `soytony/android_device_motorola_roadstr` commit
*"roadstr: Rename sun-common to sm7750-common in dependencies"* — the reference tree called
`sm7750-common` is the renamed **`sun-common` (SM8750)** tree. marvel was built from an SM8750
reference.

### (b) The init file that starts the touch probe was never copied

`recovery/touch_probe.sh` existed, but the init file lived at `init/init.qcom.recovery.rc`
(not `recovery/root/init.recovery.qcom.rc`) and `orangefox_marvel.mk` only copied `twrp.flags`
and `touch_probe.sh`. So even the probe script that existed never ran.

### (c) The probe itself was wrong for marvel

`touch_probe.sh` probed `focaltech_v3_4`, `goodix_core`, `focaltech_touch`, `novatek_touch`,
`synaptics_tcm2` — and never loaded `mmi_info` / `mmi_relay`, which the MMI touch stack needs
before `touchscreen_mmi`. It also did not account for `modules.blocklist`, which **deliberately
blocks** `goodix_brl_mmi`, `goodix_fod_mmi` and `rbs_fod_mmi`.

## The fix

```make
# package the modules
BOARD_VENDOR_KERNEL_MODULES        := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)

# make the recovery ramdisk self-contained
BOARD_RECOVERY_KERNEL_MODULES      := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)

# let TWRP's inbuilt loader do its thing too
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := "$(wildcard .../*.ko) ..."
```

plus a force-loader for the MMI touch chain and a correct `modules.load.recovery`.

## Verification performed

- `recovery.img` header: `kernel_size: 0`, empty cmdline → ramdisk-only ✔
- recovery ramdisk contains the corrected `system/etc/recovery.fstab` ✔
- sha256 of the local image matched the server build output exactly ✔
- on-device `fastboot getvar partition-size:*` matched every `BOARD_*_PARTITION_SIZE` except `dtbo`
  (see `01-device-tree-analysis.md`) ✔
- Motorola ABL behaviour: kernel-less image → *"No OS could be found"*; kernel-present image →
  normal boot into the installed OS (this is why `fastboot boot` cannot test this recovery) ✔
