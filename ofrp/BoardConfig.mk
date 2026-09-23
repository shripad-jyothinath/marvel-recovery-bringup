#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Motorola Edge 70 Fusion (marvel) — OrangeFox / TWRP device tree
# Rewritten: correct kernel-module packaging + loading, removed roadstr leftovers.
#

DEVICE_PATH := device/motorola/marvel

# Build
ALLOW_MISSING_DEPENDENCIES := true
SOONG_ALLOW_MISSING_DEPENDENCIES := true
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
# NOTE: TARGET_CPU_VARIANT_RUNTIME was "oryon" (an SM8750/Oryon value). marvel is
# SM7635 "volcano" with Kryo cores and this Soong does not even know "oryon",
# so it was silently ignored. Leave it unset rather than lying to the compiler.

# Bootloader & Assert Devices
TARGET_BOOTLOADER_BOARD_NAME := marvel
TARGET_OTA_ASSERT_DEVICE := marvel,marvel_g,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4
TARGET_DEVICE_ALT := marvel,XT2605,XT2605-1,XT2605-2,XT2605-3,XT2605-4
TARGET_NO_BOOTLOADER := true

# Display (1220 x 2712 @ 144Hz)
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

# Filesystem Config
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/config.fs

# GPS
BOARD_VENDOR_QCOM_GPS_LOC_API_HARDWARE := default

# Kernel (Prebuilt GKI 6.1, android14-6.1)
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true
BOARD_USES_GENERIC_KERNEL_IMAGE := true
TARGET_KERNEL_VERSION := 6.1
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_KERNEL_HEADERS := $(DEVICE_PATH)/prebuilt/kernel-headers.tar.gz
BOARD_KERNEL_IMAGE_NAME := Image

BOARD_KERNEL_CMDLINE += \
    video=vfb:640x400,bpp=32,memsize=3072000 \
    nosoftlockup \
    console=ttynull \
    qcom_geni_serial.con_enabled=0 \
    pstore.compress=none \
    printk.devkmsg=on \
    mem.enable_mglru=1 \
    firmware_class.path=/vendor/firmware_mnt/image

# NOTE: androidboot.roadstr_init_probe=trace_actions removed (roadstr leftover).
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
# Kernel Modules
#
# The previous tree only set the *_LOAD lists and never the module lists, and
# the branch had no modules/ directory, so the recovery image shipped with ZERO
# .ko files. That is why touch, the volume keys and all USB (adb/MTP/fastbootd)
# were dead in recovery.
# ---------------------------------------------------------------------------
BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.system_dlkm 2>/dev/null))
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load 2>/dev/null))
BOARD_SYSTEM_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.systemdlkm_blocklist
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(DEVICE_PATH)/modules.blocklist

BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.vendor_boot 2>/dev/null))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := $(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(DEVICE_PATH)/modules.load.recovery 2>/dev/null))

# Recovery must be self-contained: package the full vendor module set into the
# recovery ramdisk and load the recovery list from it. (The vendor ramdisk is
# not guaranteed to be loaded when ABL boots the recovery partition.)
BOARD_RECOVERY_KERNEL_MODULES := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)

BOOT_KERNEL_MODULES := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
SYSTEM_KERNEL_MODULES := $(BOARD_SYSTEM_KERNEL_MODULES_LOAD)

# ---------------------------------------------------------------------------
# TWRP module loading — tell TWRP where the modules are and which to load.
# `goodix_brl_mmi` / `goodix_fod_mmi` / `rbs_fod_mmi` are in modules.blocklist
# on purpose (Motorola loads the right touch driver on demand), so recovery has
# to pull them in explicitly.
# ---------------------------------------------------------------------------
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := \
    "$(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko) \
     $(wildcard $(DEVICE_PATH)/modules/vendor_boot/*.ko) \
     touchscreen_mmi.ko goodix_brl_mmi.ko goodix_fod_mmi.ko rbs_fod_mmi.ko panel_event_notifier.ko \
     mmi_info.ko mmi_relay.ko mmi_annotate.ko sensors_class.ko"

# Metadata
BOARD_USES_METADATA_PARTITION := true

# Platform (Qualcomm SM7635 / "volcano")
BOARD_USES_QCOM_HARDWARE := true
TARGET_BOARD_PLATFORM := volcano

BOARD_ROOT_EXTRA_SYMLINKS := \
    /vendor/fsg:/fsg

# Dynamic Partitions
-include vendor/lineage/config/BoardConfigReservedSize.mk
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
# Actual on-device dtbo partition is 0x02100000 = 34603008. The old 37748736
# produced a dtbo.img larger than the partition (flash would fail).
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

# Recovery
# marvel's ABL boots the recovery partition as a ramdisk-only boot image and
# takes the kernel from `boot`. If recovery.img contains a kernel the boot
# chain is treated as a normal boot and the installed OS starts instead.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_GRAPHICS_FORCE_USE_LINELENGTH := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom

# RIL
ENABLE_VENDOR_RIL_SERVICE := true

# SELinux
-include device/qcom/sepolicy_vndr/SEPolicy.mk
-include device/lineage/sepolicy/libperfmgr/sepolicy.mk
-include hardware/motorola/sepolicy/qti/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Verified Boot (Motorola AVB)
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true

# WiFi
BOARD_WLAN_DEVICE := qcwcn
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_PRIVATE_LIB_EVENT := "ON"
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wlan"
WIFI_DRIVER_STATE_OFF := "OFF"
WIFI_DRIVER_STATE_ON := "ON"
WIFI_FEATURE_HOSTAPD_11AX := true
WIFI_HIDL_FEATURE_AWARE := true
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WPA_SUPPLICANT_VERSION := VER_0_8_X

# ---------------------------------------------------------------------------
# OrangeFox Recovery Project (OFRP) Configuration
# ---------------------------------------------------------------------------
OF_SCREEN_H := 2712
OF_STATUS_H := 96
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_CLOCK_POS := 1
OF_USE_GREEN_LED := 0
OF_FLASHLIGHT_ENABLE := 0
OF_HIDE_NOTCH := 1
OF_ALLOW_DISABLE_NAVBAR := 0
OF_MAINTAINER := "Shripad"
FOX_VERSION := "R12.1"
FOX_BUILD_TYPE := "Unofficial"
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_USE_MAGISKBOOT := 1
OF_USE_MAGISKBOOT_FOR_ALL_PATCHES := 1
OF_DONT_KEEP_LOG_HISTORY := 1
OF_NO_RELOAD_AFTER_DECRYPTION := 1
OF_SKIP_MULTIUSER_FOLDERS_BACKUP := 1
OF_RUN_POST_FORMAT_PROCESS := 1
OF_QUICK_BACKUP_LIST := "/boot;/init_boot;/dtbo;/vendor_boot;/data;"
FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER := 1
FOX_ENABLE_APP_MANAGER := 1
FOX_DELETE_AROMAFM := 1
FOX_REPLACE_TOOLBOX_GETPROP := 1
OF_USE_TWRP_SAR_DETECT := 1

# ---------------------------------------------------------------------------
# TWRP UI & Hardware Features
# ---------------------------------------------------------------------------
TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := "en"
TW_SCREEN_BLANK_ON_BOOT := true
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_MTP_DEVICE := "motorola edge 70 fusion"
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1200
TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone0/temp
# NOTE: "hbtp_vm" is a MediaTek touch device (copied from the cybert tree).
# TW_INPUT_BLACKLIST is a list of input-device name *substrings*, not a regex.
# Left commented out; add entries if a phantom input device shows up.
# TW_INPUT_BLACKLIST := "goodix_brl_mmi"
TW_EXCLUDE_APEX := true
TW_EXCLUDE_PYTHON := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_FB2PNG := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FASTBOOTD := true
TW_USE_TOOLBOX := true
TW_HAS_DOWNLOAD_MODE := true
TARGET_USES_MKE2FS := true
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_EXCLUDE_TWRPAPP := true

# Decryption / Encryption (FBE v2 & Metadata decryption)
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_USE_FSCRYPT_POLICY := 2

# Security Patch
VENDOR_SECURITY_PATCH := 2026-03-01

# Inherit proprietary vendor configs
-include vendor/motorola/marvel/BoardConfigVendor.mk
