# 12 — Stock recovery ramdisk: USB root cause + the real fstab

Everything here comes from the **stock `recovery.img`** in
`DumprX` release `marvel-W2WE36.56-32-ST3.2-390dea`, asset `marvel-boot-images.tar.zst`.
All seven image MD5s match `flashfile.xml`, so the dump is authentic.

## 12.1 The stock recovery image

```
header_version = 4
kernel_size    = 0            <- ramdisk-only, NO kernel
ramdisk_size   = 19245719
```

ramdisk: 5 LZ4-legacy blocks → 36,921,088 bytes cpio → 489 entries (449 files).

**Modules in the ramdisk: 0.**

That is the decisive fact: Motorola's stock recovery is both kernel-less *and* module-less. So a
custom recovery does **not** need to bundle modules — it needs to load them from the mounted
vendor/vendor_boot. This is exactly what `TW_LOAD_VENDOR_MODULES` does, and what
`chkndrp/device_xiaomi_amethyst-recovery` (same SM7635) uses.

It also retro-validates `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`.

## 12.2 USB root cause

Stock `init.recovery.qcom.rc`:

```
on property:ro.boot.usbcontroller=*
    setprop sys.usb.controller ${ro.boot.usbcontroller}
    wait /sys/bus/platform/devices/${ro.boot.usb.dwc3_msm:-a600000.ssusb}/mode
    write /sys/bus/platform/devices/${ro.boot.usb.dwc3_msm:-a600000.ssusb}/mode peripheral
    wait /sys/class/udc/${ro.boot.usbcontroller} 1
```

Stock `prop.default`:

```
ro.recovery.usb.vid=22B8
ro.recovery.usb.adb.pid=2E81
ro.recovery.usb.fastboot.pid=2E80
# Removed by post_process_props.py because overridden by ro.recovery.usb.vid=22B8
#ro.recovery.usb.vid?=18D1
# Removed by post_process_props.py because overridden by ro.recovery.usb.adb.pid=2E81
#ro.recovery.usb.adb.pid?=D001
# Removed by post_process_props.py because overridden by ro.recovery.usb.fastboot.pid=2E80
#ro.recovery.usb.fastboot.pid?=4EE0
ro.adb.secure=1
ro.recovery.ui.margin_height=110
```

So there are **two** independent reasons adb/USB never came up on the custom builds:

1. **The dwc3 is never put into peripheral mode.** Nothing in any of the custom trees wrote
   `/sys/bus/platform/devices/a600000.ssusb/mode`. Until that is written the controller stays in
   host/OTG mode, no gadget is registered, and the host sees *nothing at all* — which is exactly
   the reported behaviour ("Device Manager doesn't even update when plugged in").
2. **Wrong USB identity.** The custom recovery carried the AOSP defaults
   (`ro.recovery.usb.vid=18D1`, `adb.pid=D001`, `fastboot.pid=4EE0` — visible in the built
   `prop.default`), for which a typical Windows host has **no driver**. The device's own history
   on that laptop showed only Motorola entries:
   `USB\VID_22B8&PID_2E80`, `USB\VID_22B8&PID_2E81`, `USB\VID_22B8&PID_2E82`.
   `22B8:2E81` is the stock recovery's adb identity — with it the existing Motorola drivers bind.

(There was also a stale phantom `usb\vid_18d1&pid_0d02` ADB node with ProblemCode 10 on that
laptop from an earlier failed driver install — another reason 18D1 never worked there.)

## 12.3 The authoritative fstab

Stock `system/etc/recovery.fstab` (BSD-licensed header stripped):

```
system              /system       erofs   ro   wait,slotselect,avb=vbmeta_system,logical,first_stage_mount
system              /system       ext4    ro,barrier=1,discard  wait,slotselect,avb=vbmeta_system,logical,first_stage_mount
system_ext          /system_ext   erofs   ro   wait,slotselect,avb=vbmeta_system,logical,first_stage_mount
product             /product      erofs   ro   wait,slotselect,avb=vbmeta_system,logical,first_stage_mount
vendor              /vendor       erofs   ro   wait,slotselect,avb,logical,first_stage_mount
#odm                /odm          erofs   ro   wait,slotselect,avb,logical,first_stage_mount      <-- COMMENTED OUT
/dev/block/bootdevice/by-name/metadata  /metadata  f2fs  noatime,nosuid,nodev,discard  wait,check,formattable,wrappedkey,first_stage_mount
/dev/block/bootdevice/by-name/userdata  /data      f2fs  noatime,nosuid,nodev,discard,reserve_root=32768,resgid=1065,fsync_mode=nobarrier
      latemount,wait,check,formattable,fileencryption=ice,wrappedkey,
      keydirectory=/metadata/vold/metadata_encryption,quota,reservedsize=128M,
      sysfs_path=/sys/devices/platform/soc/1d84000.ufshc,checkpoint=fs
/dev/block/bootdevice/by-name/boot      /boot   emmc  defaults  defaults
/dev/block/by-name/misc                 /misc   emmc  defaults  defaults
```

Corrections this makes to the earlier hand-written fstab:

| item | was | stock (correct) |
|---|---|---|
| `/data` encryption | `fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`, `metadata_encryption=…` | **`fileencryption=ice,wrappedkey`** |
| `/metadata` | `ext4` in the very first version | `f2fs` + `wrappedkey` + `first_stage_mount` |
| `odm` line | active | **commented out** (no `odm` partition) |
| `product`/`system_ext`/`vendor` types | erofs + ext4 | erofs only (both is fine, keep both to mount either OS) |
| `avb_keys=/avb/…gsi…` | present (copied from amethyst) | **absent** on stock marvel |
| `sysfs_path` | `…/1d84000.ufshc` | **confirmed** |

## 12.4 What the stock recovery bundles

Selected inventory (449 files):

- `init.recovery.qcom.rc` (4448 B) — USB + bootdevice symlink
- `system/etc/recovery.fstab` (3765 B)
- `prop.default` (29424 B)
- `res/images/*` — AOSP recovery UI assets (incl. `factory_data_reset_text.png`,
  `cancel_wipe_data_text.png`)
- `system/bin/hw/android.hardware.boot-service.qti.recovery`,
  `android.hardware.health-service.qti_recovery`,
  `android.hardware.fastboot-service.example_recovery`
- `res/` + a full busybox-ish `system/bin` (adbd, fastbootd, e2fsdroid, fsck.erofs, fsck.f2fs, …)

**No `/vendor/bin/hw` crypto services** — they are used from the mounted vendor partition.

## 12.5 Resulting tree changes

| file | change |
|---|---|
| `recovery/root/init.recovery.usb.rc` | **new** — verbatim stock USB config (peripheral mode + 22B8/2E81/2E80) |
| `BoardConfig.mk` | `TW_EXCLUDE_DEFAULT_USB_INIT := true` |
| `system.prop` | `ro.recovery.usb.vid/adb.pid/fastboot.pid`, `ro.recovery.ui.margin_height` |
| `recovery/root/system/etc/recovery.fstab` | `/data` → `fileencryption=ice,wrappedkey`; `/metadata` → stock form |
| `README.md` | documents the USB root cause and the stock-ramdisk findings |
