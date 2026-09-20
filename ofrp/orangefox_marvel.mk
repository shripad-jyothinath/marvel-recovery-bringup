#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: Apache-2.0
#

# Recovery API level override for Android 12.1 base
PRODUCT_SHIPPING_API_LEVEL := 32

# Inherit from standard product configs
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device configuration
$(call inherit-product, device/motorola/marvel/device.mk)

# Recovery partition flags and touch probe loader
PRODUCT_COPY_FILES += \
    device/motorola/marvel/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags \
    device/motorola/marvel/recovery/touch_probe.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/touch_probe.sh

# Product metadata
PRODUCT_NAME := orangefox_marvel
PRODUCT_DEVICE := marvel
PRODUCT_BRAND := motorola
PRODUCT_MODEL := motorola edge 70 fusion
PRODUCT_MANUFACTURER := motorola
PRODUCT_GMS_CLIENTID_BASE := android-motorola
