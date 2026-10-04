# 10 — Stock dump validation (`W2WE36.56-98-19`, Android 16)

Source: `dump_motorola_marvel/` — `all_build_props.txt`, `flashfile.xml`, `servicefile.xml`
(stock firmware `motorola/marvel_g/marvel:16/W2WE36.56-98-19/421c6f-2d7396:user/release-keys`,
region RETIN / `cid50`, modem `M7635_DE314_07.99.01.60R`).

## 10.1 Findings from the tree that the stock dump confirms

| earlier claim | stock prop | verdict |
|---|---|---|
| shipping API should be **36**, not 34 | `ro.build.version.sdk=36`, `ro.build.version.release=16`, **`ro.product.first_api_level=36`**, `ro.board.first_api_level=34` | ✅ `PRODUCT_SHIPPING_API_LEVEL := 34` in `common.mk`/`device.mk` **is wrong** |
| `vendor.gatekeeper.is_security_level_spu=0` is required but missing | `vendor.gatekeeper.is_security_level_spu=0` | ✅ **missing from the tree** |
| USB controller `a600000.dwc3` | `vendor.usb.controller=a600000.dwc3` | ✅ confirmed |
| platform is `volcano` | `ro.board.platform=volcano`, `ro.product.board=marvel` | ✅ confirmed |
| QTI gatekeeper/keystore stack | `ro.hardware.keystore_desede=true`, `vendor.gatekeeper.is_security_level_spu=0` | ✅ QTI, not MobiCore |
| metadata key handling | `ro.crypto.metadata_init_delete_all_keys.enabled=true` | ✅ present (the tree has it in `vendor.prop`) |
| fingerprint vendor | `ro.hardware.fingerprint=goodix` | ✅ Goodix (matches Goodix BRL touch family) |
| camera topology | `ro.vendor.qti.va_aosp.support=1` | ✅ present in `system_ext.prop` |

**Stale value:** the tree sets `VENDOR_SECURITY_PATCH := 2026-03-01`; stock is
`ro.vendor.build.security_patch=2026-07-01`, `ro.build.version.security_patch=2026-07-01`.

## 10.2 The authoritative partition inventory (from `flashfile.xml`)

The stock flash file is a better source of truth than the hand-written fstab. Partitions flashed
by the factory:

```
partition, bootloader, vbmeta, vbmeta_system, radio, bluetooth, dsp, logo,
boot, init_boot, vendor_boot, dtbo, recovery, pvmfw, super (20 sparse chunks)
```

erased on flash: `apdp`, `apdpb`, `debug_token`, `carrier`, `userdata`, `metadata`, `ddr`

Files + MD5s (useful for verifying anything extracted later):

| partition | file | md5 |
|---|---|---|
| partition | `gpt.bin` | `b5d383470a904f79a12dfb9ab51042e1` |
| bootloader | `bootloader.img` | `acd35b31c42850c1b9e7e77d1436903e` |
| vbmeta | `vbmeta.img` | `79ea683f43e4a7b3907ed0e708139394` |
| vbmeta_system | `vbmeta_system.img` | `3b3b8d7e78de46e1896a890689e2fc7e` |
| radio | `radio.img` | `8a02fd9a97befd9adfa0feb2c4327843` |
| bluetooth | `BTFM.bin` | `459e33738aab5d91c0c22c26438915b4` |
| dsp | `dspso.bin` | `bb6d6df3ce6f8d7fc664a328808daf02` |
| logo | `logo.bin` | `fac22a4147c4890a24b378987239ded7` |
| **boot** | `boot.img` | `2a9f8a24cd5fa3cc2d163dbcd89e9c8f` |
| **init_boot** | `init_boot.img` | `09da4a0b4ac2d8ed6983dd007965a6e3` |
| **vendor_boot** | `vendor_boot.img` | `b142b2bd41e5bf24916456b6bd2f3fcb` |
| **dtbo** | `dtbo.img` | `1abb00ec3806930e979b6b3b55d0fd3a` |
| **recovery** | `recovery.img` | `be4883136408c38cef82fccfd9d515b1` |
| pvmfw | `pvmfw.img` | `ac4d6684ad941f6733c10d4f772efac4` |
| super | `super.img_sparsechunk.0..19` | `b56c0dc4…`, `2c7600c9…`, … |

Notes:
- `pvmfw` exists → the platform has a protected VM firmware partition.
- `apdp` / `apdpb` are erase-only (Motorola APDP debug policy).
- `max-sparse-size = 536870912` (512 MiB).
- `super` ships as 20 sparse chunks.

## 10.3 Where the actual images live

`dump_motorola_marvel/README.md` points at GitHub **Releases** for the compressed assets:

| asset | contents |
|---|---|
| `marvel-boot-images.tar.zst` | `boot.img`, `dtbo.img`, `vendor_boot.img`, `init_boot.img`, `recovery.img`, `radio.img`, `vbmeta.img`, `vbmeta_system.img` |
| `marvel-vendor.tar.zst` | complete extracted `vendor/` partition (HALs, blobs, camera/audio configs, sensor calibrations, firmware) |
| `marvel-system.tar.zst` | extracted `system/` + `system_ext/` |
| `marvel-product.tar.zst` | extracted `product/` |

These are what the rebranded tree needs:

- `marvel-boot-images` → `prebuilt/kernel` (from `boot.img`, or the stock `Image`),
  `prebuilt/dtb/`, `prebuilt/dtbo.img`
- `marvel-vendor` → the crypto service binaries
  (`…strongbox-nxp`, `weaver-service.nxp`, `authsecret-service.nxp-qti`,
  `secure_element-service.qti`, `qseecomd`, `ssgtzd`, `keymint-service-qti`,
  `gatekeeper@1.0-service-qti`) and their `/vendor/lib64` dependencies, plus
  `/vendor/firmware_mnt/image/*` and `ueventd.rc`

## 10.4 Corrections this implies for the trees

1. `PRODUCT_SHIPPING_API_LEVEL := 34` → **36** (and drop the `SPOOF_FIRST_API_LEVEL_32` side-effect).
2. Add `vendor.gatekeeper.is_security_level_spu=0` to the vendor props.
3. `VENDOR_SECURITY_PATCH` → 2026-07-01 (or newer), matching stock.
4. `dtbo` partition 34603008 — consistent with the stock `dtbo.img`.
5. `pvmfw` is a real partition; `prebuilt/pvmfw.img` may be needed for a full flash.
