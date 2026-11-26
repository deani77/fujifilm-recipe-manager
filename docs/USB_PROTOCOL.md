# X-M5 USB protocol foundation — 27 November 2026

## Implementation status

`FujifilmPTP.swift` adds offline property identifiers, an X-M5 reference profile,
and bounded decoders for raw 16-bit values and bank names. It does not construct
or send commands, select banks, translate library recipes, or enable uploads.
The app continues to expose only the existing identity inspector. No camera
session or PTP command was executed for this addition. USB enumeration on the
owner's Mac observed vendor `0x04CB`, product `0x030C` and a 480 Mbps link;
this does not establish firmware, USB mode, or recipe compatibility.

## Transport

The documented recipe path uses PTP over USB bulk endpoints. Integers are
little-endian. A container has a 12-byte header: uint32 total length, uint16
type, uint16 operation/response code, uint32 transaction ID. Types 1/2/3/4
represent command/data/response/event. Validate sizes, status and transaction
before decoding a payload; serialize transactions and impose deadlines.

| Operation | Code |
| --- | --- |
| GetDeviceInfo | `0x1001` |
| OpenSession / CloseSession | `0x1002` / `0x1003` |
| GetDevicePropDesc | `0x1014` |
| GetDevicePropValue | `0x1015` |
| SetDevicePropValue | `0x1016` |

These operations are a reference, not an expanded inspector allowlist.
The expected camera menu mode for future recipe work is **USB RAW CONV./BACKUP
RESTORE**. USB product ID alone cannot identify mode; IDs may vary. Apple
ImageCaptureCore's `requestSendPTPCommand` is the existing macOS adapter path.
Descriptor failure or an omitted advertised property does not conclusively
establish whether a value is supported. Do not sweep unknown properties.

## Banks and values

`0xD18C` is an edit selector; `0xD18D` is the addressed bank's name. The 23
settings occupy `0xD18E` through `0xD1A4`; the Swift enum names every entry.
`0xD1A5` concerns live image size and is deliberately outside the bank catalog.
A bank read addresses the selector's bank, which may differ from the shooting
bank. Reading C1–C4 requires selector writes and is not a strictly read-only
operation. A future authorized importer must retain and restore the original
selector, reporting restoration failure rather than assuming it succeeded.

Payload words are retained as raw UInt16 bits; negative signed values require
Int16 interpretation. Display scaling and enums must be implemented per
property, not inferred from the library's numbers. The name decoder accepts
both empty representations (`00` and `01 00 00`) and validates UCS-2 length,
termination and characters. Unknown numeric values remain representable.
Unsupported fields must stay distinct from zero or an absent library setting.

## X-M5 evidence and limits

The reference's camera chapter records an owner test of X-M5 firmware **1.30**:
four banks, end-to-end reads/writes, and persistence after restart. FilmKit
issue #18 independently supplies a connection log with C1–C4 names, rejected
C5–C7 selection, and RAW conversion. That log alone does not prove bank writes.
These are upstream reports, not local validation of the owner's camera.

Do not assume all advertised bank fields are useful or writable. In particular,
Smooth Skin (`0xD198`) has conflicting capability evidence on the X-M5; preserve
its raw value and do not add a write based on an accepted unchanged value.
RAW conversion and whole-camera backup/restore use separate flows, absent here.

## Next implementation boundary

Follow [SAFETY.md](SAFETY.md) before any hardware test. Preserve an untouched
official backup privately; recipe JSON and a property snapshot are not full
camera backups. Identify actual model/firmware/mode first. Then add a separately
gated bank importer, property-specific decoding, and synthetic transaction tests.
A future writer needs a reviewed diff for one still bank, dependency-aware
ordering, stop-on-error behavior, field read-back, unrelated-field comparison,
and restart verification. No automatic restore or blind retry after partial writes.

## Sources and attribution

Protocol summary and mapping adapted from **zgrimz and contributors,
Fujifilm PTP reference**, revision
[`d78c79b7558169bace8cace483daf6975eb148aa`](https://github.com/zgrimz/fujifilm-ptp-reference/tree/d78c79b7558169bace8cace483daf6975eb148aa),
under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Changes: condensed into an X-M5 implementation note and Swift identifier catalog;
added local status, decoder boundaries and development gates. Upstream material
is provided as-is with the [license's warranty disclaimer](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/LICENSE).
No upstream executable code, captures, camera backups or photos are bundled.

- [Transport](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/01-transport.md)
- [Property catalog](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/02-properties.md)
- [Bank behavior](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/04-custom-slots.md)
- [Body-specific evidence](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/07-cameras.md)
- [FilmKit X-M5 report](https://github.com/eggricesoy/filmkit/issues/18)
- [Official X-M5 settings backup workflow](https://fujifilm-dsc.com/en/manual/x-m5/connections/save_load_setting/)
- [Apple PTP pass-through API](https://developer.apple.com/documentation/imagecapturecore/iccameradevice/requestsendptpcommand(_:outdata:completion:))

Fujifilm's separate [Camera Control SDK](https://www.fujifilm-x.com/global/camera-control-sdk/)
lists the X-M5 for image transfer/basic controls, but that does not establish
custom-bank APIs. Its proprietary license and individual-use warranty warning
need separate review if that SDK is considered. It is not included here.
