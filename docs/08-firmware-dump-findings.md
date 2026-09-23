# 08 — Firmware dump findings (marvel, `WWE36V.56-32-ST3.2-390dea`)

Source: `dumps.tadiphone.dev/dumps/motorola/marvel` →
`.../vendor_dlkm/lib/modules/{modules.dep,modules.load,modules.alias}`

This is a real marvel dump, so it supersedes anything inferred from the SM8750 reference tree.

## 8.1 The touch dependency chain (from `modules.dep`)

```
/vendor/lib/modules/goodix_brl_mmi.ko: /vendor/lib/modules/touchscreen_mmi.ko \
    /vendor/lib/modules/mmi_relay.ko /vendor/lib/modules/mmi_info.ko \
    /vendor/lib/modules/mmi_annotate.ko /vendor/lib/modules/panel_event_notifier.ko \
    /vendor/lib/modules/sensors_class.ko

/vendor/lib/modules/touchscreen_mmi.ko: /vendor/lib/modules/mmi_relay.ko \
    /vendor/lib/modules/panel_event_notifier.ko /vendor/lib/modules/sensors_class.ko

/vendor/lib/modules/mmi_info.ko:   /vendor/lib/modules/mmi_annotate.ko
/vendor/lib/modules/mmi_relay.ko:
/vendor/lib/modules/mmi_annotate.ko:
/vendor/lib/modules/panel_event_notifier.ko:
/vendor/lib/modules/sensors_class.ko:
```

**Correct load order (dependencies first):**

```
mmi_annotate → mmi_info → mmi_relay → panel_event_notifier → sensors_class
   → touchscreen_mmi → goodix_brl_mmi
```

And `modules.load` additionally carries:

```
panel_event_notifier.ko
mmi_annotate.ko
mmi_info.ko
mmi_relay.ko
sensors_class.ko
touchscreen_mmi.ko
goodix_fod_mmi.ko
mmi_stow.ko
rbs_fod_mmi.ko
goodix_brl_mmi.ko
```

> **Correction to my earlier work:** `panel_event_notifier.ko` belongs to the **touch** chain, not
> just the display chain. It was missing from the touch module lists in `twrp/` and `ofrp/`. Fixed
> in this repo.

`modules.alias` confirms the controller:

```
alias of:N*T*Cgoodix,gt9897 goodix_brl_mmi
alias of:N*T*Cgoodix,gt9966 goodix_brl_mmi
alias of:N*T*Cgoodix,gt9916 goodix_brl_mmi
alias i2c:goodix_ts goodix_brl_mmi
alias platform:goodix_ts goodix_brl_mmi
```

→ **Goodix BRL (gt9897 / gt9966 / gt9916)**. No Focaltech, no ChipOne on marvel.

Note also `modules.dep` shows `msm_drm.ko` depends on `dwc3-msm.ko`, `drm_display_helper.ko`,
`panel_event_notifier.ko`, `sync_fence.ko`, `altmode-glink.ko`, `repeater.ko`, `redriver.ko`,
`fsa4480-i2c.ko`, `wcd_usbss_i2c.ko`, `ucsi_glink.ko`, `hdcp_qseecom_dlkm.ko`, `smcinvoke_dlkm.ko`,
`qseecom_proxy.ko`, `msm_ext_display.ko`, … so pulling the display stack pulls a large part of
the USB/secure chain with it.

## 8.2 Encryption / decryption stack

Per the user and confirmed by the amethyst tree (same SoC, same vendor stack):

**`weaver (nxp)` + `secure_element` + `keymint`** (+ `qseecomd`, `ssgtzd`, `gatekeeper`,
`keymint-strongbox`).

Service bring-up order (from `chkndrp/device_xiaomi_amethyst-recovery`,
`recovery/root/init.recovery.encryption.rc`):

```sh
# after the firmware partition is mounted
on property:twrp.firmware.mounted=true
    start vendor.qseecomd

# after qseecomd registers its listeners
on property:vendor.sys.listeners.registered=true
    start vendor.ssgtzd
    start vendor.keymint-qti
    start vendor.gatekeeper-qti

# when /data is encrypted and firmware is mounted
on property:ro.crypto.state=encrypted && property:twrp.firmware.mounted=true
    start vendor.keymint-strongbox
    start vendor.weaver
    start vendor.secure_element

# after successful decryption, tear everything down again
on property:twrp.all.users.decrypted=true
    stop keystore2
    stop vendor.secure_element
    stop se_omapi
    stop vendor.weaver
    stop vendor.keymint-strongbox
    stop vendor.keymint-qti
    stop vendor.qseecomd
    stop vendor.ssgtzd
    stop vendor.gatekeeper-qti
```

This matches `vendor/motorola/marvel/config.fs`, which owns exactly these services
(`keymint-service.strongbox-nxp`, `weaver-service.nxp`, `authsecret-service.nxp-qti` — and the
Thales equivalents) with `AID_VENDOR_SSGTZD`.

Recovery flags needed:

```make
TW_INCLUDE_CRYPTO               := true
TW_INCLUDE_CRYPTO_FBE           := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_INCLUDE_OMAPI                := true
BOARD_USES_QCOM_FBE_DECRYPTION  := true
```

and the fstab must carry the wrapped-key form:

```
fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0,
metadata_encryption=aes-256-xts:wrappedkey_v0,
keydirectory=/metadata/vold/metadata_encryption,
sysfs_path=/sys/devices/platform/soc/1d84000.ufshc
```

`/metadata` must be `f2fs` with `wrappedkey`.

## 8.3 `1d84000.ufshc` confirmed

Back in `docs/06-self-review.md` I flagged `sysfs_path=/sys/devices/platform/soc/1d84000.ufshc`
as *unverified* (it came from the SM8750 reference). The amethyst tree — same SM7635 — uses the
same address:

```
wait /sys/bus/platform/devices/1d84000.ufshc
write /sys/bus/platform/devices/1d84000.ufshc/auto_hibern8 0
```

**Now confirmed.**

## 8.4 Build with the `twrp_16` manifest

To have a chance at working decryption, build against the experimental Android-16 TWRP manifest:

```sh
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp_16
repo sync
```

(`chkndrp`'s amethyst README notes the Android 16 decryption blobs do **not** work with the
official TWRP 14.1 / OrangeFox 14.1 manifests — only the Android 16 manifest does. The amethyst
tree's default branch is `fox_14.1`, so the manifest/decryption combination is the thing that
matters.)

## 8.5 Impact on the trees in this repo

| item | change |
|---|---|
| touch module list | add `panel_event_notifier.ko` (dependency of `touchscreen_mmi.ko` and of `goodix_brl_mmi.ko`) |
| touch load order | `mmi_annotate → mmi_info → mmi_relay → panel_event_notifier → sensors_class → touchscreen_mmi → goodix_brl_mmi` |
| optional extras | `goodix_fod_mmi.ko`, `mmi_stow.ko`, `rbs_fod_mmi.ko` (present in `modules.load`) |
| crypto | `TW_INCLUDE_OMAPI := true` + the `weaver/secure_element/keymint` bring-up above |
| fstab | `/metadata` f2fs + `wrappedkey`; `/data` wrapped-key form |
| manifest | `TWRP-Test/platform_manifest_twrp_aosp` `twrp_16` |
| `1d84000.ufshc` | confirmed, no longer an unverified assumption |
