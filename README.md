# marvel — recovery bring-up analysis & fixed device trees

Deep analysis and fix work for the **Motorola Edge 70 Fusion (`marvel`, XT2605)** custom
recovery bring-up.

| | |
|---|---|
| SoC | Qualcomm **SM7635 "volcano"** (Kryo), GKI **6.1** (`android14-6.1`) |
| Stock OS | Android 16 (`motorola/marvel_gh/marvel:16/W2WE6.56-98-19`) |
| Partitions | A/B, dynamic `super`, **dedicated 128 MB `recovery` partition** |
| Recovery layout | **ramdisk-only** image, kernel taken from `boot` by ABL |
| ROM being built | Evolution X 17 (from `lineage-24.0` based `vendor/lineage`) |

## The problem

The custom recovery **booted but was unusable**: black-screen/bootloop (Lineage recovery), and in
the OrangeFox/TWRP build it booted to a working UI with **dead touch, dead volume keys and no USB
at all** — no adb, no MTP, no fastbootd, Windows never even enumerated the device.

## Root cause (one line)

**The recovery image shipped with zero kernel modules and nothing loaded them.**
The `ofrp` branch set only the module *load lists* and never the module lists, and had no
`modules/` directory at all, so `build-image-kernel-modules-dir` copied nothing.

Consequences:

| missing module | symptom |
|---|---|
| `touchscreen_mmi` / `goodix_brl_mmi` | no touch |
| input drivers for the volume keys | volume keys dead |
| `dwc3-msm` + `usb_f_*` | no USB gadget → no adb / MTP / fastbootd, no USB enumeration |

Display survived because the panel/DRM path comes up early — which is why the UI appeared while
everything else was dead.

## Contents

```
docs/01-device-tree-analysis.md     deep analysis: device/motorola/marvel (evox-a17)
docs/02-vendor-tree-analysis.md     deep analysis: vendor/motorola/marvel
docs/03-root-cause.md               the zero-modules bug + evidence
docs/04-cybert-vs-marvel.md         vendor_boot recovery vs dedicated recovery partition
docs/05-encryption-and-touch.md     crypto framework + touch module chain
docs/06-self-review.md              critical review of the fixes in this repo
docs/07-gold-commits.md             reference commits mined from other trees
docs/08-firmware-dump-findings.md   marvel firmware dump: exact touch chain + decryption stack
docs/09-rebrand-plan.md             plan to rebrand the SM7635 amethyst tree for marvel
twrp/                               pure TWRP device tree for marvel
ofrp/                               OrangeFox (OFRP) device tree for marvel
scripts/                            apply / install scripts
```

## The fix, in three lines

```make
BOARD_VENDOR_KERNEL_MODULES        := $(wildcard $(DEVICE_PATH)/modules/vendor_dlkm/*.ko)
BOARD_RECOVERY_KERNEL_MODULES      := $(BOARD_VENDOR_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD)
```

plus a force-loader for the Motorola MMI touch chain (the Goodix BRL driver is in
`modules.blocklist`, so it is never auto-loaded).

## Reference policy used

| Area | Source |
|---|---|
| Qualcomm / Snapdragon / A-B / GKI / crypto / USB | **official TeamWin trees** (`lemonadep`, `genevn`, `pacman`, `pissarro`) |
| Motorola-specific (MMI touch, panel, mmi init) | **cybert tree** (Moto Edge 60 Pro, MT6897) |
| Same SoC (SM7635) behaviour | **amethyst** (Redmi Note 14 Pro+, OFRP) |

See `docs/07-gold-commits.md`.
