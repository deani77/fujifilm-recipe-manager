# Technical feasibility — 23 November 2026

## Conclusion

An offline Swift/SwiftUI recipe library is feasible independently of camera access. macOS USB/PTP communication is plausible through Apple's ImageCaptureCore, but X-M5 C1–C4 read/write support remains **unverified**. No camera was connected, enumerated, queried, or modified during this research. Firmware and USB mode of the user's camera are unknown.

Fujifilm officially supports saving/loading X-M5 camera settings over USB using FUJIFILM TETHER APP in USB RAW CONV./BACKUP RESTORE mode. This establishes an official backup workflow, not a public recipe API, backup-file schema, or third-party per-bank editing guarantee. Older material refers to X Acquire; the current X-M5 manual names TETHER APP. [Official procedure](https://app.fujifilm-dsc.com/en-int/manual/x-m5/connections/save_load_setting/), [USB modes](https://app.fujifilm-dsc.com/en-int/manual/x-m5/connections/network_usb_menu/index.html).

## Evidence and confidence

| Question | Evidence | Assessment |
| --- | --- | --- |
| Does X-M5 have C1–C4? | Official shooting-mode manual describes four custom banks and still/movie assignment. | Documented; not a seven-bank camera. |
| Can official software save/load settings? | X-M5 manual documents USB backup/restore. | Documented; backup completeness and recovery on this unit not tested. |
| Can third-party software read/write individual banks? | FujiSync implements vendor properties on other bodies. | Credible candidate; X-M5 not in its confirmed matrix. |
| Does macOS expose PTP commands? | ImageCaptureCore `requestSendPTPCommand`. | API exists; visibility and behavior in X-M5 backup mode untested. |
| Is a dump of recipe properties a full backup? | Upstream recipe protocol excludes whole-camera backup blobs. | No; non-recipe settings and unknown fields can be missing. |
| Does a successful PTP response prove persistence? | Upstream notes warn that OK may not mean the value took effect. | No; later reads, reconnect checks and recovery evidence are required. |
| Can iPhone USB reuse the Mac implementation? | No device/OS test performed. | Unresolved; keep transport platform-specific. |

The X-M5 combines X-Trans CMOS 4 with X-Processor 5. Do not infer protocol compatibility from either generation alone. [Official specifications](https://www.fujifilm-x.com/global/products/cameras/x-m5/specifications/).

Custom banks can contain exposure and other shooting settings as well as image rendering parameters. They can be assigned to stills or movies. A future recipe writer must preserve bank type and unrelated settings. The film simulation dial can override the saved simulation depending on its position; a bank readback alone does not establish the active shooting look. [Shooting modes](https://app.fujifilm-dsc.com/en/manual/x-m5/taking_photo/shooting_mode/index.html), [dial behavior](https://app.fujifilm-dsc.com/en-int/manual/x-m5/about_this_camera/parts/index.html).

## FujiSync and the candidate recipe protocol

Reviewed FujiSync at [`ec570e91`](https://github.com/ILFforever/FujiSync/tree/ec570e91c2713332480a28cd5765d7df26c8e4a9) and its community protocol documentation at [`6bb63c90`](https://github.com/ILFforever/fujifilm-ptp-recipes/tree/6bb63c9007a497111ae38d1a363ae30be98a0fd9). These are independent reverse-engineered sources, not Fujifilm guarantees.

The [protocol description](https://github.com/ILFforever/fujifilm-ptp-recipes/blob/6bb63c9007a497111ae38d1a363ae30be98a0fd9/docs/protocol.md) identifies standard PTP operations GetDeviceInfo (`0x1001`), GetDevicePropDesc (`0x1014`), GetDevicePropValue (`0x1015`) and SetDevicePropValue (`0x1016`). Its candidate Fujifilm properties are:

- `0xD18C`: selects a custom bank.
- `0xD18D`: bank name.
- `0xD18E`–`0xD1A4`: bank property block; only mapped and supported fields should ever be considered for writing.
- `0xD192`: film simulation within that bank block.

These identifiers are research leads only; no executable protocol constants are added in Phase 1. The upstream seven-slot indexing must not be carried over beyond C4. C1–C4 numeric mapping, selector semantics, bank assignment behavior, supported properties, encodings and name limits all need X-M5 evidence.

**A bank read can require a write.** FujiSync's [`FujiRecipeCamera.readPreset`](https://github.com/ILFforever/FujiSync/blob/ec570e91c2713332480a28cd5765d7df26c8e4a9/app/src/main/java/com/ilfforever/fujisync/data/usb/FujiRecipeCamera.kt) calls `selectSlot`, which sends SetDevicePropValue for `0xD18C`, before reading. It is not eligible for a strict no-settings-modification investigation. Whether that selector is transient or persistent on X-M5 is unknown. Reading without selection, if supported, cannot establish a full C1–C4 dump or be labelled as live shooting state.

The [protocol status report](https://github.com/ILFforever/fujifilm-ptp-recipes/blob/6bb63c9007a497111ae38d1a363ae30be98a0fd9/docs/protocol-status.md) records working paths on X-H2, X-T5 and X-T30 II, with X-Pro3 failures. X-M5 is absent from that tested matrix. X-M5 appears in [static capability analysis](https://github.com/ILFforever/fujifilm-ptp-recipes/blob/6bb63c9007a497111ae38d1a363ae30be98a0fd9/docs/reverse-engineering/xrfc-capability-database.md), but those RAW-conversion feature records are not proof of custom-bank USB support. Do not import Fujifilm binaries or extracted tables into this project.

The reviewed code and documentation differ on delays and supported scope. Name limits, whole/half-step tones, signed values, white-balance shifts, grain packing, dynamic-range priority, monochrome dependencies and firmware-specific optional fields need individual validation. No “best effort” clamping or silent omission should be presented as a faithful backup or successful upload.

## Other implementation options

- [libgphoto2 PTP driver](https://github.com/gphoto/libgphoto2/blob/6d5c61ef7687b74fe792e4aeae7fc40f2ad42d88/camlibs/ptp2/library.c) lists X-M5, USB VID/PID `04cb:030c`, with capture/preview flags. This supports investigating transport; it does not establish C1–C4 recipe coverage. Its initialization can perform vendor setup; do not assume a CLI diagnostic is side-effect-free.
- [libpict](https://github.com/petabyt/libpict/tree/753a1c6f5b49fb7c006215b26c8c915da965c782) is a C PTP transport library with USB and PTP/IP backends. It advertises no stable release. An adapter would bring C interoperability and backend packaging work.
- [libfuji](https://github.com/petabyt/libfuji/tree/59034fb7aa26a7a62f9c20e2f5f9442454753c1f) adds Fujifilm modes. Its [`fuji_usb.c`](https://github.com/petabyt/libfuji/blob/59034fb7aa26a7a62f9c20e2f5f9442454753c1f/lib/fuji_usb.c) has whole-backup download and restore routines, separate from recipe properties: download reads object handle 0 in RAW-conversion transport; restore sends object information and data. These are useful leads, not a verified X-M5 recovery implementation. Do not execute them in initial research.
- [Apple ImageCaptureCore](https://developer.apple.com/documentation/imagecapturecore/iccameradevice/requestsendptpcommand(_:outdata:completion:)) is the preferred first macOS transport investigation because it provides native PTP pass-through. Check capability, session ownership, container handling, permissions, cancellation and error behavior. Apple documents a USB entitlement requirement for sandboxed access on macOS 14+. A Swift package build does not validate a sandboxed app bundle. [Framework documentation](https://developer.apple.com/documentation/imagecapturecore).

## Risks and limits

1. Unsupported or partially applied writes could overwrite bank contents or unrelated settings. No transaction atomicity or guaranteed rollback is established.
2. A property-only snapshot can omit unknown values, custom white-balance calibration or broader camera configuration. Official backup exclusions and firmware compatibility must be verified rather than inferred from older-body instructions.
3. Interrupted writes, power loss, busy sessions and other software owning the camera can leave uncertain state. Future writes must stop on ambiguity and require recovery review.
4. USB product IDs and advertised property lists are insufficient capability proof. Unknown model/firmware combinations must stay unsupported; no automatic brute-force probing.
5. Firmware changes can invalidate mappings. Capture exact identity with every future diagnostic and backup.
6. iPhone USB permissions, transport access, accessory behavior and distribution requirements need separate investigation. Shared Swift models do not imply shared USB support.

Recommendation: approve an offline library and strictly read-only discovery stage first. Hold selector changes, per-bank enumeration and all uploads behind a separate safety review and explicit authorization after an official original backup is available. See [SAFETY.md](SAFETY.md).

Attribution: protocol descriptions above summarize Fuji PTP Recipes contributors' documentation (CC BY 4.0), linked at the reviewed revision. This report reorganizes and assesses that material for X-M5 safety; it is not a verbatim copy. No upstream code was reused.
