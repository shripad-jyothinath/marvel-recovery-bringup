#
# Copyright (C) 2026 The Team Win Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# Motorola Edge 70 Fusion (marvel / XT2605) — pure TWRP device tree
# Platform: Qualcomm SM7635 "volcano" (GKI 6.1, Android 16 stock)
#
# Reference policy:
#   * Qualcomm / Snapdragon / A-B / GKI / crypto  -> official TeamWin trees
#       - TeamWin/android_device_oneplus_lemonadep   (SM8350, A/B, Qualcomm)
#       - TeamWin/android_device_motorola_genevn     (Motorola Qualcomm)
#       - TeamWin/android_device_nothing_pacman      (modern module handling)
#   * Motorola-specific (MMI touch stack, panel, mmi init) -> cybert tree
#

DEVICE_PATH := device/motorola/marvel

# Build
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true
TARGET_USES_VULKAN := true
TARGET_DISABLE_VIBRATOR := true

# Board API Level
BOARD_API_LEVEL_PROP_OVERRIDE := 202404

# A/B & Virtual A/B
AB_OTA_UPDATER := true

AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    product \
    recovery \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_dlkm \
    vendor_boot

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := kryo
# TWRP is 64-bit only on this device (gold: a16xm "Force the TWRP to 64-bit and
# drop the legacy 32-bit support").
TARGET_IS_64_BIT := true
TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true

# Bootloader & assert
TARGET_BOOTLOADER_BOARD_NAME := marvel
TARGET_OTA_ASSERT_DEVICE := marvel,marvel_g,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4
TARGET_DEVICE_ALT := marvel,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_WIDTH := 1220
TARGET_SCREEN_HEIGHT := 2712
TARGET_SCREEN_DENSITY := 440

# Init boot
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# DTB / DTBO
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb
TARGET_NEEDS_DTBOIMAGE := true
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# Filesystem config
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/config.fs

# Kernel (prebuilt GKI 6.1 / android14-6.1)
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_KERNEL_VERSION := 6.1
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_KERNEL_HEADERS := $(DEVICE_PATH)/prebuilt/kernel-headers.tar.gz

BOARD_KERNEL_CMDLINE += \
    video=vfb:640x400,bpp=32,memsize=3072000 \
    nosoftlockup \
    console=ttynull \
    qcom_geni_serial.con_enabled=0 \
    pstore.compress=none \
    printk.devkmsg=on \
    mem.enable_mglru=1 \
    firmware_class.path=/vendor/firmware_mnt/image

BOARD_BOOTCONFIG += \
    androidboot.hardware=qcom \
    androidboot.memcg=1 \
    androidboot.usbcontroller=a600000.dwc3 \
    androidboot.load_modules_parallel=true \
    androidboot.hypervisor.protected_vm.supported=true \
    androidboot.vendor.qspa=true \
    androidboot.adb_early=1 \
    androidboot.init_fatal_panic=true \
    androidboot.selinux=permissive \
    androidboot.serialconsole=0

# ---------------------------------------------------------------------------
# Kernel modules
#
# Gold: lemonadep "add missing firmware files and let TWRP load kernel modules",
#       "switch to inbuilt TWRP logic for loading modules",
#       genevn "Implement proper modules loading",
#       pacman "Fix vendor ramdisk kernel modules handling".
#
# marvel boots recovery from a dedicated recovery partition as a ramdisk-only
# image (kernel comes from `boot`), so the recovery ramdisk must be
# self-contained - it cannot rely on vendor_boot being loaded.
# ---------------------------------------------------------------------------
BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load 2>/dev/null))
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.blocklist
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.system_dlkm 2>/dev/null))
BOARD_SYSTEM_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.systemdlkm_blocklist

BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.vendor_boot 2>/dev/null))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := $(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.recovery 2>/dev/null))

# Make recovery self-contained.
BOARD_RECOVERY_KERNEL_MODULES := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)

BOOT_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
SYSTEM_KERNEL_MODULES := $(BOARD_SYSTEM_KERNEL_MODULES_LOAD)

# Let TWRP's inbuilt loader bring up the vendor/boot modules as well.
# gold: lemonadep "let TWRP load kernel modules"; a16xm "exclude GKI kernel modules"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := \
    "$(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko) \
     $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)"

# Metadata
BOARD_USES_METADATA_PARTITION := true

# Platform
BOARD_USES_QCOM_HARDWARE := true
TARGET_BOARD_PLATFORM := volcano

BOARD_ROOT_EXTRA_SYMLINKS := \
    /vendor/fsg:/fsg

# Dynamic partitions
-include vendor/lineage/config/BoardConfigReservedSize.mk
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 34603008
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_BUILD_VENDOR_RAMDISK_IMAGE := true

BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_SUPER_PARTITION_SIZE := 21474836480
BOARD_MOT_DP_GROUP_PARTITION_LIST := product system system_dlkm system_ext vendor vendor_dlkm
BOARD_SUPER_PARTITION_GROUPS := mot_dp_group
BOARD_MOT_DP_GROUP_SIZE := 21470642176
BOARD_FLASH_BLOCK_SIZE := 262144
# gold: genevn "Kill BOARD_HAS_LARGE_FILESYSTEM", amethyst "include BOARD_HAS_NO_REAL_SDCARD"
BOARD_HAS_NO_REAL_SDCARD := true

TARGET_COPY_OUT_ODM := vendor/odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

# Properties
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# ---------------------------------------------------------------------------
# Recovery
# gold: genevn "Move recovery.fstab to system/etc directory",
#       "Exclude the Default USB Init", "Add TARGET_USE_CUSTOM_LUN_FILE_PATH"
# ---------------------------------------------------------------------------
# marvel's ABL boots the recovery partition as a ramdisk-only boot image and
# takes the kernel from `boot`. A kernel inside recovery.img makes the boot
# chain do a normal boot and start the installed OS instead.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_DEVICE_DIRS += $(DEVICE_PATH)
TARGET_RECOVERY_QCOM_RTC_FIX := true
# gold: lemonadep "use los default qcom usb init rc" - do NOT exclude the default
# USB init; TWRP's Qualcomm USB configfs init is well tested. We only need to
# set sys.usb.controller (see init.recovery.qcom.rc).
TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun.%d/file

# RIL
ENABLE_VENDOR_RIL_SERVICE := true

# SELinux
-include device/qcom/sepolicy_vndr/SEPolicy.mk
-include device/lineage/sepolicy/libperfmgr/sepolicy.mk
-include hardware/motorola/sepolicy/qti/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Verified boot (Motorola AVB)
# gold: genevn "Set UTC date to 0", "Spoof vendor security patch with
# anti-rollback hack", "Use RSA4096 key also for vbmeta_system"
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true

# Anti-rollback hack (gold: genevn / pissarro / a16xm)
PLATFORM_SECURITY_PATCH := 2099-12-31
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# WiFi (recovery rarely needs it, kept for completeness)
BOARD_WLAN_DEVICE := qcwcn
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
WPA_SUPPLICANT_VERSION := VER_0_8_X

# ---------------------------------------------------------------------------
# TWRP configuration
# gold: lemonadep (UI/modules/USB), genevn (Motorola Qualcomm), a16xm (modern)
# ---------------------------------------------------------------------------
TW_THEME := portrait_hdpi
TW_FRAMERATE := 60
TW_DEVICE_VERSION := marvel_v2.0.0
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := "en"
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_MTP_DEVICE := "motorola edge 70 fusion"

# gold: lemonadep "remove quotes from TW_BRIGHTNESS_PATH"
TW_BRIGHTNESS_PATH := /sys/class/backlight/panel0-backlight/brightness
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1200
TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone0/temp
# Do not blank the panel on boot (gold: genevn "Disable blank screen on boot")
TW_NO_SCREEN_TIMEOUT := true

# Do not let TWRP grab a spurious input device.
# NOTE: TW_INPUT_BLACKLIST is a list of input-device name *substrings*, not a
# regex. Left commented out; add entries (e.g. "hbtp_vm") if a phantom input
# device shows up in recovery.
# TW_INPUT_BLACKLIST := "goodix_brl_mmi"

# Crypto / decryption (gold: genevn "Enable TW_INCLUDE_CRYPTO",
# "Use fscrypt policy v2", "Let qcom common decryption tree handle decryption")
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_USE_FSCRYPT_POLICY := 2

# Tools (gold: lemonadep "include lpdump, lptools, fb2png",
#                 genevn "Build resetprop and libresetprop", "Enable NTFS-3G")
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_LPTOOLS := true
TW_EXCLUDE_LPDUMP := true
TW_INCLUDE_FB2PNG := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FASTBOOTD := true
TARGET_USES_MKE2FS := true
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_TWRPAPP := true

# gold: genevn "Advertise EDL mode"
TW_HAS_DOWNLOAD_MODE := true

# NOTE: marvel HAS a dedicated recovery partition (unlike cybert, which is a
# vendor_boot recovery: TW_HAS_NO_RECOVERY_PARTITION := true +
# BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT). Do NOT set
# TW_HAS_NO_RECOVERY_PARTITION here - TWRP treats it as "defined = true".

# Inherit proprietary vendor configs
-include vendor/motorola/marvel/BoardConfigVendor.mk
