#
# Copyright (C) 2026 The Team Win Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# Minimal TWRP device config for marvel. Recovery only needs dynamic
# partitions, fastbootd and the health/boot HALs.
#

DEVICE_PATH := device/motorola/marvel

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

# fastbootd + boot/health HALs
# gold: lemonadep "switch to boot hal 1.2", genevn "Build fastbootd"
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.1-impl-mock \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery \
    android.hardware.health-service.qti \
    android.hardware.health-service.qti_recovery

# Filesystem tools
PRODUCT_PACKAGES += \
    e2fsck.vendor_ramdisk \
    fsck.f2fs.vendor_ramdisk \
    resize2fs.vendor_ramdisk \
    tune2fs.vendor_ramdisk

# Crypto / keystore
# gold: genevn "keymaster: make sure to start km 4.1 when km 4.0 sb is started"
PRODUCT_PACKAGES += \
    android.hardware.security.keymint \
    android.hardware.security.secureclock \
    android.hardware.security.sharedsecret \
    android.hardware.hardware_keystore.xml

# emulated storage (gold: genevn "Inherit emulated storage")
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Shipping API level (stock marvel shipped Android 16)
PRODUCT_SHIPPING_API_LEVEL := 36

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)
