# 13 — Official TWRP device trees: 1,147 of them, and what they say about marvel

Scan requested to answer three questions: **how has the official TWRP tree set been maintained**,
**does any of it conflict with our device**, and **is anything in our tree a brick risk**. The
short answers: it's mostly an archive with a small active core, ours is idiomatic with two
deliberate deviations, and the only hard-brick vector our tree had has been closed.

Everything here is from the live GitHub API (`TeamWin` and `TWRP-Test` orgs), GitHub code search,
and AOSP's own `avbtool` run against the stock images in the dump. Raw scans:
`sm7635_trees.json`, `twrp_orgs.json` in the temp workspace.

---

## 1. The official set, measured

| | |
|---|---|
| public repos in `TeamWin` | **1,379** |
| repos named `android_device_*` | **1,147** (600 of them forks, 0 archived) |
| Motorola trees | **70** |
| any `marvel` / `volcano` / XT2605 tree | **none** |
| `TWRP-Test` (the org whose manifest we build against) | 39 repos, **1** device tree: `android_device_google_emux64` (an emulator, branch `main`) |

### Maintenance over time

| year | trees created | trees last pushed |
|---|---|---|
| 2012 | 39 | 15 |
| 2013 | 44 | 12 |
| 2014 | 42 | 7 |
| **2015** | **206** (peak) | 5 |
| 2016 | 173 | **223** |
| 2017 | 130 | 122 |
| 2018 | 106 | 89 |
| 2019 | 103 | 83 |
| 2020 | 72 | 122 |
| 2021 | 74 | 128 |
| **2022** | 44 | **146** |
| 2023 | 23 | 53 |
| 2024 | 37 | 66 |
| 2025 | 41 | 38 |
| 2026 (so far) | 13 | 38 |

Recent activity: **12 trees touched in the last 90 days (1.0%), 52 in 12 months (4.5%), 79 in 24
months (6.9%), 398 in 5 years (34.7%).** Two thirds of the official set has not been touched in
five years. Peak maintenance was 2020–2022; current rate is ~38 trees/year, about a quarter of peak.

### Generations

Branch names across the 60 most recently pushed trees: `android-12.1` (30), **`android-14.1` (11)**,
`android-16` (6), `android-9.0` (10), plus legacy `lineage-*`/`cm-*`. The `android-16` trees are all
2026-era Samsung A-series: `m55xq`, `a17x`, `a35x`, `m35x`, `a25ex`, `a16x`.

**Our `twrp-16.0` target is the current frontier of TWRP, not a lagging choice**, and those six
Samsung trees are the only directly comparable reference set in the official org.

### Motorola subset (70 trees)

Most recent: `fogo` (2025-06), `penangf` (2025-05), `corfu` (2024-11), `astro`, `rhodep`, `bangkk`,
`fogos`, `guamp`, `rhode`, `liber`, `caprip`, `genevn` (2023-09)… Default branches are
`android-12.1`/`android-11`. **No Motorola tree exists for marvel, volcano or any SM7635 Moto.**

---

## 2. Convention comparison — where we match and where we deviate

Our tree's shape — `AndroidProducts.mk` + `BoardConfig.mk` + `device.mk` + `twrp_<device>.mk` +
`recovery/root/system/etc/twrp.flags` + `prebuilt/` — is exactly the shape of the Android-16
Samsung trees. Deviations, all deliberate:

| item | official practice | ours | why |
|---|---|---|---|
| `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` | 3 trees in the org (`genevn`, xiaomi `sapphire`, `sm4635-common`) **and** the same-SoC Fairphone FP6 and Nothing `asteroids` trees | `true` | stock marvel recovery is `kernel_size = 0`; this is the **chipset-standard** answer on SM7635/volcano, not an exotic hack |
| `/vbmeta` + `/vbmeta_system` in `twrp.flags` | 20 official trees mention vbmeta; **5 of the 6 Android-16 trees expose it as flashable** (`flashimg`) | **backup-only** (no `flashimg`) | marvel verifies the recovery partition (see §3). Writing an arbitrary vbmeta is the one UI action that can leave this device unbootable. Documented deviation. |
| `/persist_image` | commonly `flashimg=1` | **backup-only** | sensor/camera calibration; restorable from backup, not recoverable without a stock dump |
| `slotselect` | every official Motorola tree uses it on `boot`/`dtbo`/`vendor_boot`/`vbmeta`/`recovery` | same, unchanged | see §4 — an earlier claim of mine that marvel might be single-slot was wrong |
| `BOARD_AVB_RECOVERY_*` signing | `genevn` signs its recovery image (test key, RSA4096) | added to match | we had `BOARD_AVB_ENABLE := true` with no key for the recovery partition |
| `TW_HAS_NO_RECOVERY_PARTITION` | 11 official trees set it — all devices *without* a dedicated recovery partition | **absent** | TWRP treats *defined* as true; setting it even to `false` breaks recovery handling. marvel has a dedicated 128 MB recovery partition. |
| `BOARD_USES_RECOVERY_AS_BOOT` | 16 official trees set it (recovery-in-boot devices) | empty | marvel's recovery is its own partition |
| `BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT` | 1 official tree | empty | not applicable |

Nothing in the official set conflicts with our device — there is simply no official tree for it,
and the closest siblings (`genevn`, `guamp`) agree with our structure.

---

## 3. Brick analysis — the part that matters

### 3.1 Stock `vbmeta.img` verifies the recovery partition

```
$ python avbtool.py info_image --image vbmeta.img
Minimum libavb version:  1.0            Algorithm: SHA256_RSA4096
Rollback Index:          7              Flags:     0
Descriptors:
    Chain Partition descriptor: vbmeta_system   (rollback index location 2)
    Hash descriptor: boot         35659776 bytes   Flags: 0
    Hash descriptor: dtbo           598379 bytes   Flags: 0
    Hash descriptor: init_boot     2105344 bytes   Flags: 0
    Hash descriptor: pvmfw          774144 bytes   Flags: 0
    Hash descriptor: recovery     19251200 bytes   Flags: 0   <-- verified
    Hash descriptor: vendor_boot   8826880 bytes   Flags: 0
    Hashtree descriptor: product     6198493184 bytes
    Hashtree descriptor: system_dlkm   11653120 bytes
    ...
```

`Flags: 0` on the recovery hash descriptor means verification is **enabled**. This is the single
fact that decides the flashing risk, and it is why the usual TWRP advice does not apply verbatim
to this device.

### 3.2 What happens when you flash TWRP to `recovery`

| bootloader state | outcome |
|---|---|
| **unlocked** (required to `fastboot flash` at all) | verification failure is tolerated → recovery boots, with the standard "device is unlocked / can't be verified" warning |
| **locked / relocked** | the bootloader refuses to boot a partition that fails AVB → **never relock the bootloader while TWRP is installed**. On Motorola, relocking also wipes userdata. |

The change is confined to one partition. Our build outputs only `recovery.img` and
`ramdisk-recovery.img`; `BOARD_USES_RECOVERY_AS_BOOT` and
`BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT` are empty; `boot`, `init_boot`, `vendor_boot`,
`dtbo`, `vbmeta`, `super` and the installed OS are untouched. The OS never verifies `recovery` at
runtime, so normal booting is unaffected.

### 3.3 Do **not** touch vbmeta

The advice that is common for other devices:

```sh
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img    # DO NOT
```

is **not required** here (nothing about running TWRP depends on it) and it modifies a signed,
verified-boot component — the operation that can leave the device unbootable or force a data wipe.
The same reasoning is why `twrp.flags` now lists `/vbmeta` and `/vbmeta_system` as backup-only:
backup and restore keep working, arbitrary writes are no longer offered in the UI.

### 3.4 Reverting is one command

The byte-exact stock recovery image is in the dump and its MD5 matches `flashfile.xml`:

```sh
fastboot flash recovery stock_recovery.img
```

That restores the verified state. (Note the dump's file is 13,421,728 bytes — the boot image
itself — while vbmeta hashes 19,251,200 bytes, i.e. the image plus AVB padding/footer; reflashing
the stock file restores a matching image, since avbtool hashes the whole padded region and the
bootloader re-derives the same content.)

### 3.5 `fastboot boot` cannot be used to try it

Marvel's ABL requires a kernel-less recovery image (`kernel_size = 0`). `fastboot boot` of a
kernel-less image fails with "No OS could be found"; booting a kernel-present image just boots the
installed OS. The only test path is: flash the recovery partition, then enter recovery from the
bootloader menu.

### 3.6 Partitions that must never be exposed — verified absent

The stock `servicefile.xml` shows the full flash set, including `bootloader`, `partition`, `ddr`,
`apdp`/`apdpb`, `debug_token`, `carrier`, `logo`, `radio`, `pvmfw`. Writing a wrong `bootloader` or
`partition` image is a *hard* brick (EDL/blankflash territory). Our `twrp.flags`/`recovery.fstab`
expose **none** of them: no `abl`, `xbl`, `bootloader`, `partition`, `ddr`, `apdp`, `debug_token`.
What *is* flashable (`boot`, `init_boot`, `vendor_boot`, `dtbo`, `recovery`, the logical images) is
normal TWRP capability and recoverable over fastboot.

---

## 4. Correction: the single-slot claim

I earlier suggested marvel's physical partitions might be single-slot (stock recovery fstab has no
`slotselect` on `boot`; `servicefile.xml` lists unsuffixed names). **That was wrong and I retract
it.** The vendor-matched evidence says the opposite:

| tree | structure | `slotselect` used on |
|---|---|---|
| `genevn` | Motorola, kernel-less recovery, dedicated recovery partition, A/B | `boot`, `dtbo`, `vendor_boot`, `vbmeta`, `vbmeta_system`, `recovery` |
| `guamp` | Motorola, `BOARD_USES_RECOVERY_AS_BOOT := false` + dedicated 100 MB recovery partition — **marvel's exact shape** | `boot`, `dtbo`, `vbmeta`, `recovery`, `dsp` |
| `corfu` | Motorola, recovery-as-boot, `TW_HAS_NO_RECOVERY_PARTITION := true` | `boot`, `vendor_boot`, `vbmeta`, `dtbo` |
| `fogo`, `bangkk`, `rhode` | Motorola A/B | `boot`, `dtbo`, `vendor_boot`, `vbmeta`, `vbmeta_system` |

Both of my evidence points were weak: the stock recovery fstab's `boot` entry has no `slotselect`
because **stock recovery never flashes boot** (it is `emmc defaults`, never mounted), and the
servicefile lists unsuffixed names because **Motorola's flashing tool resolves the active slot**,
exactly as `fastboot flash boot` appends `_a`/`_b`.

**Decisive on-device check** (10 seconds in any shell):

```sh
ls /dev/block/bootdevice/by-name/ | grep -E 'boot|recovery|vbmeta|dtbo'
# boot_a boot_b ... -> slotted (expected);  boot ... -> single
```

A wrong guess here is a *soft* failure either way — TWRP logs "unable to find partition" for that
entry — never a brick. No change made.

---

## 5. CPU side: SM7635 / "volcano" across all vendors

Core components are chipset-driven; only the vendor bits should be Motorola-specific. Code search
found the same-SoC tree set (`SM7635 filename:BoardConfig.mk` → 28 files), including Fairphone
**FP6** (LineageOS, CalyxOS, aospa, fp6-aosp), Nothing **asteroids** (many forks), Xiaomi
**amethyst**/**flute**/**flourite**, Realme RMX5070, Oppo sm6650, OnePlus OP64D3L1 — and our base
tree `chkndrp/device_xiaomi_amethyst-recovery`.

| variable | SM7635 convention | ours | verdict |
|---|---|---|---|
| `TARGET_BOARD_PLATFORM` | `volcano` (all) | `volcano` | ✓ |
| `TARGET_CPU_ABI` | `arm64-v8a` | `arm64-v8a` | ✓ |
| `TARGET_CPU_VARIANT_RUNTIME` | `kryo300` (asteroids, fp6-aosp) | `kryo300` | ✓ — inherited, now verified against the SoC |
| `TARGET_CPU_VARIANT` | `generic` / `kryo` / `cortex-a76` | `generic` | ✓ (only used for host/target matching) |
| `BOARD_KERNEL_PAGESIZE` | `4096` | `4096` | ✓ |
| `BOARD_BOOT_HEADER_VERSION` | `4` | `4` | ✓ |
| `BOARD_INIT_BOOT_HEADER_VERSION` | `4` | `4` | ✓ |
| `BOARD_RAMDISK_USE_LZ4` | `true` | `true` | ✓ |
| `BOARD_USES_GENERIC_KERNEL_IMAGE` | `true` | `true` | ✓ |
| `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE` | `true` (FP6, asteroids, genevn) | `true` | ✓ chipset-standard |
| `BOARD_AVB_ENABLE` | `true` | `true` (+ recovery signing added) | ✓ |
| `BOARD_SUPER_PARTITION_SIZE` | `9663676416` (9 GiB) on FP6/asteroids | `21474836480` (20 GiB) | keep ours — **device-specific**, from the marvel dump |
| `BOARD_SUPER_PARTITION_GROUPS` | `qti_dynamic_partitions` | `mot_dp_group` | keep ours — must match the device's super metadata (Motorola naming) |
| `TARGET_BOARD_PLATFORM_GPU` | not set by the sampled trees | `qcom-adreno810` | cosmetic; unverified |

So the chipset-level configuration is consistent with every other SM7635 tree, and the two places
where we differ are the two that *must* differ because they come from the device's own super
metadata. Crypto stays vendor-specific on purpose: the stock vendor image wires **NXP**
StrongBox/Weaver/AuthSecret (`vendor.keymint-strongbox`, `vendor.weaver_nxp`, …) plus **QTI**
keymint/gatekeeper over QSEE, and those binaries/`.rc` files come from the device dump — a
Fairphone or Xiaomi tree would give the wrong crypto stack even on the same SoC.

---

## 6. On-device verification checklist (everything I cannot check without the device)

1. `ls /dev/block/bootdevice/by-name/ | grep -E 'boot|recovery|vbmeta|dtbo'` → confirm slot suffixes (§4).
2. Boot into recovery with an unlocked bootloader → expect the AVB/unlocked warning, then TWRP.
   If it refuses, the fallback is the stock recovery image (§3.4).
3. `getprop ro.boot.strongbox_support` → decides whether the NXP StrongBox/Weaver path runs.
4. Touch/USB: `dmesg | grep -E 'goodix|mmi|panel_event'` and `adb devices` (expect VID/PID `22B8`).
5. FBE: does TWRP prompt for the lockscreen PIN and mount `/data` (expect `fileencryption=ice,wrappedkey`)?
6. Backup `/vbmeta` once, then confirm restore works (this is the safety net that replaced flashing it).
