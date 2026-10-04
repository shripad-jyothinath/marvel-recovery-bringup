# marvel — recovery bring-up analysis & fixed device trees

Deep analysis and fix work for the **Motorola Edge 70 Fusion (`marvel`, XT2605)** custom
recovery bring-up.

| | |
|---|---|
| SoC | Qualcomm **SM7635 "volcano"**, GKI **6.1** (`android14-6.1`) |
| Stock OS | Android 16 — `motorola/marvel_gh/marvel:16/W2WE6.56-98-19` (dump `W2WE36.56-98-19`) |
| Partitions | A/B, dynamic `super`, **dedicated 128 MB `recovery` partition** |
| Recovery layout | **ramdisk-only** image (`kernel_size = 0`), kernel taken from `boot` by ABL |

## Deliverables

| repo | what |
|---|---|
| [`device_motorola_marvel-recovery`](https://github.com/shripad-jyothinath/device_motorola_marvel-recovery) | **buildable** recovery tree (rebranded from the SM7635 amethyst tree, blobs + prebuilts wired in) |
| **this repo** | the analysis, evidence and reference trees behind it |

## The problem

A custom recovery **booted but was unusable** — in the OrangeFox/TWRP build it reached a working UI
with **dead touch, dead volume keys and no USB at all** (no adb, no MTP, no fastbootd, Windows
never even enumerated the device), and a Lineage recovery build black-screened and rebooted.

## Root causes — three, all found in the stock dump

> **Corrected.** The first diagnosis was "the recovery ramdisk shipped zero kernel modules".
> That was **wrong** — the *stock* recovery ramdisk also contains **0 modules**. It was a red
> herring. `docs/03` records the original reasoning; `docs/06` (self-review) and `docs/12` correct
> it. The real causes are below.

### 1. USB — the QTI dwc3 is never put into peripheral mode (docs/12)

Stock `init.recovery.qcom.rc` writes:

```
write /sys/bus/platform/devices/${ro.boot.usb.dwc3_msm:-a600000.ssusb}/mode peripheral
```

No custom tree did this. Until that node is written the controller registers **no gadget**, so the
host sees *nothing whatsoever* — the exact "Device Manager doesn't even update" symptom.

### 2. USB — the wrong USB identity (docs/12)

Stock `prop.default`:

```
ro.recovery.usb.vid=22B8
ro.recovery.usb.adb.pid=2E81
ro.recovery.usb.fastboot.pid=2E80
# (overriding the AOSP defaults 18D1 / D001 / 4EE0)
```

The custom builds carried the **Google defaults**, for which a typical Windows host has **no
driver**. The device's own history on that machine showed only Motorola entries
(`VID_22B8&PID_2E80/2E81/2E82`).

### 3. Modules — nothing loaded the touch/USB drivers from vendor

`TW_LOAD_VENDOR_MODULES` was never set, so TWRP never loaded any of the vendor modules. That kills
touch (`touchscreen_mmi` → `goodix_brl_mmi`) and USB (`dwc3-msm` + `usb_f_*`). The stock recovery
gets them the same way — from the **mounted vendor partition**, not from the ramdisk.

### Bonus: recovery must be kernel-less

Removing `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` made ABL treat `recovery.img` as a normal boot
image and start the installed OS. Stock `recovery.img` is `kernel_size = 0`.

## What was verified against the device (not inferred)

- all 7 stock images match `flashfile.xml` MD5s
- `prebuilt/kernel`, `dtbo.img`, `marvel.dtb` are **byte-identical** to the stock images
- stock `recovery.fstab`: `/data` = `fileencryption=ice,wrappedkey`, `/metadata` = f2fs+`wrappedkey`,
  `odm` line **commented out**, `sysfs_path=…/1d84000.ufshc`
- crypto = **NXP** KeyMint KM300 strongbox + NXP Weaver + secure_element,
  gated on `ro.boot.strongbox_support`, with `vendor.gatekeeper.is_security_level_spu=0` needed to
  `enable vendor.gatekeeper_default`
- touch chain from the real `modules.dep`:
  `mmi_annotate → mmi_info → mmi_relay → panel_event_notifier → sensors_class → touchscreen_mmi → goodix_brl_mmi`
- shipping API is **36**, not 34 (`ro.product.first_api_level=36`)

## Contents

```
docs/01-device-tree-analysis.md         analysis: device/motorola/marvel (evox-a17)
docs/02-vendor-tree-analysis.md         analysis: vendor/motorola/marvel
docs/03-root-cause.md                   the original (partly wrong) zero-modules theory
docs/04-cybert-vs-marvel.md             vendor_boot recovery vs dedicated recovery partition
docs/05-encryption-and-touch.md         crypto framework + touch module chain
docs/06-self-review.md                  critical review of my own conclusions and mistakes
docs/07-gold-commits.md                 reference commits mined from other trees
docs/08-firmware-dump-findings.md       dump: exact touch chain + decryption stack
docs/09-rebrand-plan.md                 amethyst → marvel rebrand mapping
docs/10-stock-dump-validation.md        stock props validate the earlier findings
docs/11-crypto-sku-dnes.md              SKU-gated NXP StrongBox, stock .rc mechanisms
docs/12-stock-recovery-usb-and-fstab.md USB root cause + authoritative fstab   <-- start here
twrp/                                   reference TWRP tree (superseded by the deliverable repo)
ofrp/                                   reference OrangeFox tree
scripts/                                apply / install scripts
```

## Reference policy

| Area | Source |
|---|---|
| Qualcomm / Snapdragon / A-B / GKI / crypto / USB | **official TeamWin trees** (`lemonadep`, `genevn`, `pacman`, `pissarro`) |
| Same SoC (SM7635) behaviour — used as the rebrand base | **amethyst** (Redmi Note 14 Pro+) |
| Motorola-specific (MMI touch, panel, mmi init) | **cybert** (Moto Edge 60 Pro, MT6897) |
| Ground truth | the **stock marvel dump** |

## Status

Everything in the deliverable tree is evidence-backed, but it **has not been compiled yet**. See
`docs/06-self-review.md` for the honest list of unverified assumptions and the remaining risks.
