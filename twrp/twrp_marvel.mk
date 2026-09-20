#
# Copyright (C) 2026 The Team Win Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# TWRP product for Motorola Edge 70 Fusion (marvel)
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device configuration
$(call inherit-product, device/motorola/marvel/device.mk)

# Inherit common TWRP stuff
$(call inherit-product, vendor/twrp/config/common.mk)

# Recovery ramdisk extras.
# NOTE: the previous tree shipped touch_probe.sh but never copied the init file
# that starts it into the recovery ramdisk, so the touch probe never ran.
PRODUCT_COPY_FILES += \
    device/motorola/marvel/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    device/motorola/marvel/recovery/root/system/bin/load-mod.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/load-mod.sh \
    device/motorola/marvel/recovery/root/system/etc/recovery.fstab:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/recovery.fstab \
    device/motorola/marvel/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags \
    device/motorola/marvel/recovery/touch_probe.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/touch_probe.sh

# Product metadata
PRODUCT_NAME := twrp_marvel
PRODUCT_DEVICE := marvel
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 70 fusion
PRODUCT_MANUFACTURER := motorola
PRODUCT_GMS_CLIENTID_BASE := android-motorola

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=marvel \
    BuildDesc="marvel-user 16 W2WE6.56-98-19 421c6f release-keys" \
    BuildFingerprint=motorola/marvel_gh/marvel:16/W2WE6.56-98-19/421c6f-2d7396:user/release-keys
