# Phase 2 validation — 24 November 2026

Owner approved Phase 2 and explicitly deferred camera testing because an official original backup is not yet available. Work is on a branch based on the still-unmerged Phase 1 branch. No PR merge is implied by development approval.

## Implemented

- SwiftUI local library with create/edit/search/duplicate/delete, explicit save, source/author/notes and manual recipe display values.
- Versioned JSON import/export, a defined v0 migration, unknown-field preservation and all-or-nothing merge rules.
- Atomic local saves, previous-file retention, file locking and conflict detection; corrupt/newer files cannot silently become empty libraries.
- Experimental ImageCaptureCore discovery and identity inspector. Nothing scans on launch or when opening the sheet. User acknowledgement and clicks are required for discovery and for opening a session.
- Single fixed GetDeviceInfo command, bounded parsing, matching transaction/response validation, timeout handling, session-close cleanup and serial-number discard. No generic command interface, property read loop or data-out API.
- Development app bundle with app sandbox, USB and user-selected-file read/write entitlements. No network entitlement, networking client or analytics.

## Automated verification

Core XCTest coverage uses synthetic fixtures only:

- v0 migration; nested unknown metadata/parameters and decimal tone preservation.
- corrupt/future documents and oversized input rejection; duplicate UUID and metadata conflict rejection.
- previous-file retention, competing repository instances and external corruption protection.
- full-string numeric validation, range/step checks and unspecified-versus-zero behavior.
- PTP payload/container decoding, truncated strings/datasets, oversized arrays, response failures and transaction mismatch; serial number not retained in the identity value.

A passing parser test proves behavior for synthetic bytes, not compatibility with the ImageCaptureCore response representation on X-M5. The adapter lifecycle, entitlement effectiveness and USB-mode visibility still require an owner-led hardware test after backup. The framework manages session open/close; the app does not send raw session opcodes or enable tethering.

## Local results

Swift 6.4.2 / Xcode 27.2 on arm64 macOS: all 11 XCTest cases passed. The optimized sandboxed application bundle built and passed `codesign --verify --deep --strict`. Package-build caches were redirected for the restricted development environment; Xcode release symbol generation required running the build outside the execution sandbox. This does not disable the resulting app sandbox.

The packaged app was launched and its UI exercised through native accessibility controls. A synthetic recipe with Classic Chrome and highlight −1.5 was created/saved, exported to a user-selected local JSON file, deleted with confirmation and re-imported successfully. The synthetic entry was then deleted, leaving an empty library. Export/import worked from the sandboxed bundle. The inspector opened with its backup acknowledgement unchecked, Scan disabled and status “Not scanning”; no scan was started. A visual screenshot review showed the saved recipe detail without clipping.

On resuming on 24 November, all 11 tests passed again. Packaging now signs in a temporary folder and archives without extended attributes: iCloud-backed Documents was adding Finder metadata to loose bundles after signing. The app remains ad-hoc signed and unnotarized. CI now uses macos-15: GitHub retired macos-14 on 2 November 2026 ([official notice](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/)). The runner OS is separate from the app’s macOS 14 deployment target. CI results are recorded separately in the PR. No test asserts real hardware behavior or iPhone compatibility.

## Remaining limits

No camera enumeration, session, identity request, bank read/write, mode change or restoration has been performed. C1–C4 retrieval remains unavailable because the candidate protocol requires a slot-selector write. Identity strings and advertised property counts are not used to grant write capability.

Import/export supports this app's JSON format only. No recipe community feed, OCR, JPEG extraction, QR, camera backup decoding or iPhone app is included. Unknown values are preserved but not necessarily editable. Bank type and unrelated camera settings are not represented as a writable camera profile.

Hardware validation and Developer ID signing/notarization remain separate work. Ad-hoc signing is for local development. A licence decision is still needed before offering broad reuse terms.
