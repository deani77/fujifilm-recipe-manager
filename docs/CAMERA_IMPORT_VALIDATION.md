# X-M5 camera import — 27 November 2026

## Owner authorization and hardware result

The owner confirmed an untouched official settings backup and requested camera-to-app recipe import. They reconnected the camera in the requested USB mode. The backup itself was not opened, modified or restoration-tested.

On this Mac, the connected body identified itself through GetDeviceInfo as **X-M5, firmware 1.30**. The manual import utility read C1–C4. Every bank returned its name plus all 23 catalogued properties, with no unsupported-property responses. The original edit selector was C1; it was restored to C1 and read back successfully. Session closure completed. A schema-v1 Recipe Manager JSON file containing four recipes was saved privately outside the repository. No names, photos, serials or real property payloads are committed here.

The only camera property written was `0xD18C`, for C1, C2, C3, C4, then the original C1. No recipe settings, names, live-shooting controls, files, firmware or settings backup were written. This verifies bank retrieval and selector restoration for this body/firmware/session. It does not establish camera-side recipe upload, whole-backup recovery, menu agreement for every display mapping, or behavior on other firmware.

## ImageCaptureCore transaction correlation

Two initial identity attempts stopped before selector access: the response had OK status and a well-formed dataset, but its wire transaction did not equal the client-supplied number. One response used 3449 instead of 1. This matches the renumbering observations documented in the upstream [platform notes](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/09-platform-notes.md). A later discovery attempt found no camera; no session was opened. The owner reconnected before the successful import.

Native adapters now correlate by the request-specific completion, active operation/session and generation token. They validate response framing and status, and any wrapped data container must match the response's wire transaction and expected opcode. The standalone wire decoder retains strict expected-transaction checking for direct USB callers. Late callbacks after timeouts cannot advance the current operation. The existing identity inspector uses this same correction.

## Limits and failure handling

- CLI only; the app's camera inspector remains identity-only. Load the generated JSON through its existing import action. Existing library UUID/conflict handling still applies.
- Exactly one enumerated Fujifilm camera, X-M5 model and firmware 1.30, and a readable original selector in C1–C4 are required. Unknown profiles fail before selector writes.
- One command at a time, 15-second per-request deadlines, 100 ms after selector changes, read-back verification, and one restoration attempt. Timeout, malformed reply, disconnect or invalid-session responses invalidate the transport; no subsequent property command is sent through it.
- A known optional-property `0x200A` is retained as unsupported; name or film-simulation failure stops the import. Other errors abort. No incomplete bank set is exported as success.
- Only `0xD18C` has a data-out encoder. No recipe-setting writer, capture, RAW upload, firmware or restore command is available.
- Preserve raw values. Display decoding omits unrecognized enums/sentinels rather than replacing them with defaults. Smooth Skin, image size/quality and other non-editor fields remain in raw metadata.
- Imported custom WB modes do not include their measured calibration. Only the active WB mode's red/blue shifts are read. The saved bank is not necessarily the camera's active shooting look; dial overrides, bank assignment and unrepresented configuration remain outside this import.
- The utility is a development tool, not a notarized camera-compatible release. Its hardware run was outside the desktop sandbox; sandboxed app import has not been validated.

## Verification

22 XCTest cases passed before the successful hardware run: four-bank read order, selector-only encoding, invalid bank/profile refusal, malformed/mismatched containers, framework-renumbered identity, read failure/restoration, restoration mismatch, raw-value retention and recipe display conversion, plus the existing library tests. Native adapter timeout/callback logic received source review; no simulated disconnect or timeout was induced on the real camera.

The actual output parsed as schema v1, four recipes, 24 raw properties per recipe and verified selector restoration. Raw camera output stays private and is not a synthetic fixture.

Protocol identifiers and display tables are adapted from zgrimz and contributors' **Fujifilm PTP reference**, pinned revision `d78c79b7558169bace8cace483daf6975eb148aa`, under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This implementation condenses the tables and adds guards, parser checks and import metadata; no upstream executable code was copied. See [USB_PROTOCOL.md](USB_PROTOCOL.md#sources-and-attribution) for attribution, source and warranty-disclaimer links, and its [encoding chapter](https://github.com/zgrimz/fujifilm-ptp-reference/blob/d78c79b7558169bace8cace483daf6975eb148aa/docs/03-encodings.md) for the value mappings.
