#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# OrangeFox product for Motorola Edge 70 Fusion (marvel)
#

# Recovery API level override for the Android 12.1 (fox_12.1) base
PRODUCT_SHIPPING_API_LEVEL := 32

# Inherit from standard product configs
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device configuration
$(call inherit-product, device/motorola/marvel/device.mk)

# Recovery ramdisk extras.
# NOTE: the previous tree shipped touch_probe.sh but the init file that starts
# it was never copied into the recovery ramdisk (it lived at
# init/init.qcom.recovery.rc, not recovery/root/init.recovery.qcom.rc), so the
# touch probe never ran. Copy both explicitly here.
PRODUCT_COPY_FILES += \
    device/motorola/marvel/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    device/motorola/marvel/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags \
    device/motorola/marvel/recovery/touch_probe.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/touch_probe.sh

# Product metadata
PRODUCT_NAME := orangefox_marvel
PRODUCT_DEVICE := marvel
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 70 fusion
PRODUCT_MANUFACTURER := motorola
PRODUCT_GMS_CLIENTID_BASE := android-motorola

# Product build props (MTP device name etc.)
PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceName=marvel \
    ProductName=motorola_edge_70_fusion

# OrangeFox device version
TW_DEVICE_VERSION := marvel_v2.0.0
