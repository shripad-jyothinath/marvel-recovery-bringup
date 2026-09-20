# 05 — Encryption framework and touch modules

## Part A — Encryption framework

The question was: **Keymint + Trustonic, or Keymint + Thales (StrongBox)?**

The answer depends on the *platform*, and there are three different answers in play:

| Platform | Device | Keymint / keymaster | StrongBox / Weaver | TEE |
|---|---|---|---|---|
| **MT6897** (MediaTek) | cybert (Edge 60 Pro) | `android.hardware.security.keymint@3.0-service.trustonic` | — | **Trustonic / MobiCore** |
| **SM7635** (Qualcomm) | amethyst (Redmi Note 14 Pro+) | `android.hardware.security.keymint-service-qti` | **Thales StrongBox + Weaver + SPU** | QTI / QSEE |
| **SM7635** (Qualcomm) | **marvel (Edge 70 Fusion)** | **QTI keymint (QSEE)** | **NXP *or* Thales StrongBox/Weaver/AuthSecret** | QTI / QSEE |

### Evidence for cybert → Trustonic

- `system.prop`: `ro.hardware.gatekeeper=trustonic`, `ro.hardware.kmsetkey=trustonic`,
  `ro.vendor.mtk_tee_gp_support=1`, `ro.vendor.mtk_trustonic_tee_support=1`
- services: `android.hardware.security.keymint@3.0-service.trustonic`,
  `android.hardware.gatekeeper-service.trustonic`, `vendor.trustonic.tee@1.1-service`,
  `vendor.trustonic.tee.tui@1.0`
- `mcDriverDaemon` + MobiCore t-Drv trustlets (`*.drbin`) under `/vendor/app/mcRegistry`
- `libteeservice_client.trustonic.so`, `libMcClient.so`, `libTEECommon.so`
- modules: `t-base-tui.ko`, `mcDrvModule-ffa.ko`, `isee-ffa.ko`
- `tzapp` partition holds `.drbin`/`.tlbin` trustlets; recovery mounts it in `tee.rc`
- cybert's README explicitly credits StrongBox/OMAPI work as **investigated and dropped**

### Evidence for marvel → QTI + NXP/Thales StrongBox

From `vendor/motorola/marvel/config.fs`:

```
AID_VENDOR_NXP_STRONGBOX      2910
AID_VENDOR_NXP_WEAVER         2911
AID_VENDOR_SSGTZD             2912
AID_VENDOR_THALES_STRONGBOX   2913
AID_VENDOR_NXP_AUTHSECRET     2915
AID_VENDOR_THALES_WEAVER      2916
AID_VENDOR_THALES_AUTHSECRET  2917

[vendor/bin/hw/android.hardware.security.keymint-service.strongbox-nxp]
[vendor/bin/hw/android.hardware.weaver-service.nxp]
[vendor/bin/hw/android.hardware.authsecret-service.nxp-qti]
[vendor/bin/hw/android.hardware.security.keymint-service.strongbox-thales]
[vendor/bin/hw/android.hardware.weaver-service.thales]
[vendor/bin/hw/android.hardware.authsecret-service.thales-qti]
```

plus `AID_VENDOR_SSGTZD` → Qualcomm's Secure Services Gateway TrustZone daemon (`ssgtzd`).

`device/motorola/marvel/vendor.prop` agrees on the QTI side:

```
ro.vendor.keymaster.nonsecure_algorithm=gatekeeper
ro.hardware.keystore_desede=true
vendor.keymint.retry_timer=5
```

**Conclusion:** marvel is **not** Trustonic/MobiCore. It is Qualcomm QTI keymint/gatekeeper on
QSEE, with StrongBox/Weaver/AuthSecret provided by NXP or Thales (both binaries ship; the active
one depends on the SKU/secure element). Any attempt to port cybert's `tee.rc` / `trustonic.rc` /
`mcDriverDaemon` / `tzapp` machinery into marvel is wrong.

### What recovery actually needs

Not the full crypto stack — just enough to unwrap the metadata key:

```
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_USE_FSCRYPT_POLICY := 2
```

and the fstab must describe the real encryption:

```
fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0,
metadata_encryption=aes-256-xts:wrappedkey_v0,
keydirectory=/metadata/vold/metadata_encryption,
sysfs_path=/sys/devices/platform/soc/1d84000.ufshc
```

The tree's hand-written fstab was missing `wrappedkey_v0` / `metadata_encryption` / `sysfs_path`,
and mounted `/metadata` as `ext4` instead of `f2fs` — either of which alone breaks decryption.

## Part B — Touch modules

### marvel

Motorola "MMI" touch stack with a **Goodix BRL** controller:

```
mmi_info.ko        # MMI device info
mmi_relay.ko       # MMI relay (glue)
mmi_annotate.ko    # MMI annotation
sensors_class.ko   # input/sensor class
touchscreen_mmi.ko # MMI touch core
goodix_brl_mmi.ko  # Goodix BRL controller  <- marvel's panel
goodix_fod_mmi.ko  # under-display fingerprint
rbs_fod_mmi.ko     # FOD helper
```

Critical detail: `modules.blocklist` (from stock) contains

```
blocklist rbs_fod_mmi
blocklist goodix_fod_mmi
blocklist goodix_brl_mmi
```

so the touch controller drivers are **never auto-loaded** — the stock ROM loads the right one on
demand after probing the panel. **Recovery must force-load them**, which is what
`recovery/touch_probe.sh` / `load-mod.sh` do.

Commit `e7b6d46` (*"Remove focaltech_v3_4.ko from ramdisk modules (Marvel uses Goodix BRL)"*)
already recorded this finding.

### cybert (for comparison — triple-sourced panels)

The Motorola MT6897 family ships three touch controller variants, and the cybert tree covers all
three:

| chip | module | firmware |
|---|---|---|
| Goodix BRL | `goodix_brl_u_mmi.ko` | `goodix_*_csot.bin` |
| Focaltech | `focaltech_touch_v3_u_mmi.ko` | `focaltech_ts_fw_tianma_*.bin` |
| ChipOne | `cps4038_mmi.ko` | `cps4038.bin`, `cps4038_cn.bin` |

All three sit under `touchscreen_u_mmi.ko` (the unified MMI layer) with
`mmi_info`/`mmi_relay`/`sensors_class`/`mtk_disp_notify` as glue. marvel only needs the Goodix
one — but the *pattern* (unified MMI layer + per-chip driver + force-load) is identical, which is
why cybert is the right reference for this part.
