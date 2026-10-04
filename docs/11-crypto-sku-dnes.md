# 11 — Crypto stack: the "dnes" SKU (NXP StrongBox + Weaver)

The user was right about the stack. The evidence was in the **ODM partition**, which is why the
first pass over `vendor/bin/hw` missed it.

## 11.1 Source of truth: `odm/etc/vintf/manifest_dnes.xml`

```xml
<!--
    Input:
        device/moto/marvel/vintf/manifest_dnes.xml
        vendor/qcom/proprietary/securemsm/esehal/vintf_res/secure_element-service.xml
        vendor/nxp/opensource/keymaster/keymint/KM300/android.hardware.security.keymint-service.strongbox.xml
        vendor/nxp/opensource/keymaster/keymint/KM300/android.hardware.sharedsecret-service.strongbox.xml
        vendor/nxp/opensource/keymaster/weaver/aidl_impl/android.hardware.weaver-service.nxp.xml
-->
<manifest version="7.0" type="device">
    <hal format="aidl" override="true">
        <name>android.hardware.secure_element</name>
        <fqname>ISecureElement/SIM1</fqname>
        <fqname>ISecureElement/SIM2</fqname>
        <fqname>ISecureElement/eSE1</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.keymint</name>
        <version>3</version>
        <fqname>IKeyMintDevice/strongbox</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.keymint</name>
        <version>3</version>
        <fqname>IRemotelyProvisionedComponent/strongbox</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.sharedsecret</name>
        <fqname>ISharedSecret/strongbox</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.weaver</name>
        <version>2</version>
        <fqname>IWeaver/default</fqname>
    </hal>
    <hal format="aidl">
        <name>android.se.omapi</name>
        <fqname>ISecureElementService/default</fqname>
    </hal>
</manifest>
```

So marvel has a **SKU-gated StrongBox**: the `dnes` variant carries
**NXP KeyMint KM300 (strongbox) + NXP Weaver + secure_element + OMAPI**.

## 11.2 The SKU is selected by a permission file

`odm/etc/permissions/sku_dnes/android.hardware.strongbox_keystore.xml`:

```xml
<!-- Feature for devices with Keymaster in StrongBox. -->
<feature name="android.hardware.strongbox_keystore" version="300"/>
```

and `vendor/etc/vhw.xml` gates it:

```xml
<!-- strongbox support -->
<string name="strongbox/.auto">key=hwid;index=2;map=1:false,2:false,3:false,4:false,5:false,6:true,7:false,8:false</string>
<string name="strongbox/.chosen">mmi,</string>
<strongbox_feature export="ro.boot.strongbox_support" default="false">
    <string name="strongbox">true</string>
</strongbox_feature>
```

→ StrongBox is enabled only for specific hardware IDs (index 2, value 6), exported as
`ro.boot.strongbox_support`.

`vendor/etc/hal_uuid_map_config.xml` also names the four implementations explicitly:

```
<!-- NXP KEYMINT (UID = 2910), WEAVER (UID = 2911) -->
<!-- and AUTHSECRET (UID = 2915) mapping -->
<!-- STM KEYMINT (UID = 2913) and WEAVER (UID = 2916) mapping -->
```

which matches the AIDs in `device/motorola/marvel/config.fs`
(`AID_VENDOR_NXP_STRONGBOX 2910`, `AID_VENDOR_NXP_WEAVER 2911`, `AID_VENDOR_NXP_AUTHSECRET 2915`,
`AID_VENDOR_THALES_STRONGBOX 2913`, `AID_VENDOR_THALES_WEAVER 2916`).

**So the device ships both NXP and STM(Thales) implementations and selects one; the `dnes`
manifest says NXP.**

## 11.3 The default (non-strongbox) path

`vendor/etc/vintf/manifest/android.hardware.security.keymint-service-qti.xml` declares the
TZ-backed `IKeyMintDevice/default` (+ secureclock + sharedsecret) — that is the always-present
path, provided by `/vendor/bin/hw/android.hardware.security.keymint-service-qti`.

Present in the extracted vendor tree:

```
/vendor/bin/hw/android.hardware.security.keymint-service-qti   + .rc + .xml
/vendor/bin/hw/android.hardware.gatekeeper-service-qti         + .rc
/vendor/bin/hw/android.hardware.secure_element-service.qti     + .rc + .xml
/vendor/bin/hw/android.hardware.keymaster@4.0-service-qti
/vendor/bin/hw/vendor.qti.hardware.qseecom@1.0-service
/vendor/bin/qseecomd + .rc
/vendor/bin/ssgtzd   + .rc
/vendor/lib64/libQSEEComAPI.so, libqtigatekeeper.so, libqtikeymint.so
```

**Missing** from the extracted vendor tree (present in the ODM manifest references):
`strongbox-nxp`, `sharedsecret-service.strongbox`, `weaver-service.nxp`, `authsecret-service.nxp-qti`.
They must be extracted from the full `vendor` (or `odm`) partition — see `docs/10`.

## 11.4 What this means for recovery

Recovery must bring up **both** paths, in this order:

```
qseecomd
  → ssgtzd, keymint-qti, gatekeeper-qti          (TZ-backed, always present)
  → keymint-strongbox, weaver, secure_element    (SKU-gated: NXP on dnes)
```

i.e. exactly the sequence in `chkndrp/.../init.recovery.encryption.rc`, with the
**NXP** service binaries:

```sh
service vendor.keymint-strongbox /vendor/bin/hw/android.hardware.security.keymint-service.strongbox-nxp
service vendor.weaver            /vendor/bin/hw/android.hardware.weaver-service.nxp
service vendor.authsecret        /vendor/bin/hw/android.hardware.authsecret-service.nxp-qti
service vendor.secure_element    /vendor/bin/hw/android.hardware.secure_element-service.qti
```

**Caveat:** StrongBox is `ro.boot.strongbox_support`-gated. On a unit where the bootloader reports
`strongbox_support=false`, `vendor.keymint-strongbox`/`vendor.weaver` will fail to start — the
recovery `.rc` should tolerate that (init logs and continues; decryption still works through the
TZ `keymint-qti` path). Worth guarding the `start` behind
`property:ro.boot.strongbox_support=true` if it turns out to cause noise.
