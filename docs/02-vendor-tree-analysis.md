# 02 — Vendor tree deep analysis: `vendor/motorola/marvel`

Read-only analysis. Nothing in the vendor tree was modified.

## 1. Structure

```
Android.bp                 soong_namespace { imports: ["device/motorola/marvel"] }
Android.mk                 ifeq ($(TARGET_DEVICE),marvel) all-makefiles-under -> no-op
BoardConfigVendor.mk       -include vendor/motorola/sm7750-common/BoardConfigVendor.mk
marvel-vendor.mk           2280 lines, 2270 copy rules   (the whole tree, effectively)
README.md
proprietary/               2244 files, 835 MB
```

### `marvel-vendor.mk`
- 2270 `PRODUCT_COPY_FILES` rules, all under one `PRODUCT_COPY_FILES += \`.
- Destination roots:

| root | rules |
|---|---|
| `$(TARGET_COPY_OUT_VENDOR)` | 1572 |
| `$(TARGET_COPY_OUT_SYSTEM_EXT)` | 686 |
| `$(TARGET_COPY_OUT_ODM)` | 6 |
| `$(TARGET_COPY_OUT_PRODUCT)` | 3 |

- Line 8: `$(call inherit-product-if-exists, vendor/motorola/sm7750-common/sm7750-common-vendor.mk)`

### `proprietary/`

| dir | files |
|---|---|
| `vendor/` | 1549 |
| `system_ext/` | 686 |
| `odm/` | 6 |
| `product/` | 3 |
| **total** | **2244 files / 835 MB** |

## 2. Findings

### 2.1 The `sm7750-common` inheritance is a silent no-op (high)

`vendor/motorola/sm7750-common/` **does not exist** in the tree. Both references use `-include`
/ `-if-exists`, so they fail silently:

```make
# BoardConfigVendor.mk
-include vendor/motorola/sm7750-common/BoardConfigVendor.mk

# marvel-vendor.mk
$(call inherit-product-if-exists, vendor/motorola/sm7750-common/sm7750-common-vendor.mk)
```

The vendor README claims the tree "inherits the shared platform drivers" from
`sm7750-common`. It does not — everything the tree needs must already be in
`vendor/motorola/marvel/proprietary`.

There is a commit in history, `vendor: Remove invalid sm7750-common BoardConfigVendor include`,
which suggests this was already identified once — but the current `BoardConfigVendor.mk` still
contains the include.

### 2.2 Where the blobs actually came from (medium — documentation inconsistency)

- Vendor git log: `marvel: Extract proprietary vendor blobs from stock firmware (W2WE36.56-98-19)`
  → **marvel stock** (matches the bootloader's `motorola/marvel_gh/marvel:16/W2WE6.56-98-19`).
- `device/motorola/marvel/proprietary-files.txt` header says
  `# All unpinned blobs below are extracted from roadstr W1WRS36.39-25-2-1` → **roadstr**
  (a different, SM8750 device).

These contradict each other. The vendor repo commit is the stronger evidence (it names the
marvel build fingerprint), but the device tree's blob list was clearly derived from a roadstr
tree. Any blob that is *pinned* to a roadstr hash is suspect.

### 2.3 Crypto hardware revealed by `config.fs` (informational — this is the answer)

`config.fs` defines both NXP **and** Thales secure-element AIDs and service ownership:

```
AID_VENDOR_NXP_STRONGBOX      2910
AID_VENDOR_NXP_WEAVER         2911
AID_VENDOR_SSGTZD             2912
AID_VENDOR_THALES_STRONGBOX   2913
AID_VENDOR_NXP_AUTHSECRET     2915
AID_VENDOR_THALES_WEAVER      2916
AID_VENDOR_THALES_AUTHSECRET  2917

[vendor/bin/hw/android.hardware.security.keymint-service.strongbox-nxp]      user: AID_VENDOR_NXP_STRONGBOX
[vendor/bin/hw/android.hardware.weaver-service.nxp]                          user: AID_VENDOR_NXP_WEAVER
[vendor/bin/hw/android.hardware.authsecret-service.nxp-qti]                  user: AID_VENDOR_NXP_AUTHSECRET
[vendor/bin/hw/android.hardware.security.keymint-service.strongbox-thales]   user: AID_VENDOR_THALES_STRONGBOX
[vendor/bin/hw/android.hardware.weaver-service.thales]                       user: AID_VENDOR_THALES_WEAVER
[vendor/bin/hw/android.hardware.authsecret-service.thales-qti]               user: AID_VENDOR_THALES_AUTHSECRET
```

**marvel = Qualcomm QTI keymint/gatekeeper (QSEE) + StrongBox/Weaver/AuthSecret implemented by
NXP *or* Thales (both binaries ship), plus `ssgtzd`.**

It is **not** Trustonic/MobiCore. See `docs/05-encryption-and-touch.md`.

### 2.4 `Android.mk` is a no-op (low)

```make
LOCAL_PATH := $(call my-dir)
ifeq ($(TARGET_DEVICE),marvel)
include $(call all-makefiles-under,$(LOCAL_PATH))
endif
```

There are no other `Android.mk` files under the vendor tree, so this does nothing. All blobs are
shipped as `PRODUCT_COPY_FILES`, not as Soong/Android.mk modules — which means:
- no `install_in_root`/`owner` metadata (handled by `config.fs` instead),
- no Soong-side dependency tracking for the blobs.

### 2.5 Blob hygiene

History shows the tree has been trimmed over time:
- `marvel: Remove blobs compiled from source by ROM`
- `marvel-vendor.mk: Drop copy rules for modules built from source`
- `marvel: Fix XML version in c2pa permissions file`

Remaining concerns:
- `system_ext` carries 686 files including Motorola framework apps and permission XMLs — much of
  this is vendor-app surface that a custom ROM may not want.
- The tree ships a full `odm/etc/vintf/manifest_*.xml` set (sku_dnes etc.) with no device tree
  sepolicy for them.

## 3. Summary

| severity | finding |
|---|---|
| high | `sm7750-common` vendor inheritance is missing → silently skipped, vendor README is wrong |
| medium | blob provenance inconsistent (vendor commit says marvel stock; `proprietary-files.txt` says roadstr) |
| medium | everything is `PRODUCT_COPY_FILES` — no module metadata, no dependency tracking |
| low | `Android.mk` / `Android.bp` are effectively no-ops |
| info | `config.fs` proves the crypto stack: QTI keymint + NXP/Thales StrongBox + `ssgtzd` |
