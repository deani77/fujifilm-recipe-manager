# Fujifilm Recipe Manager

An offline-first macOS recipe notebook built with Swift and SwiftUI, initially targeting the Fujifilm X-M5. Create, edit, search, duplicate, import and export recipes on your Mac. No account or internet connection is required.

**Phase 2: offline library and experimental identity inspector. X-M5 C1–C4 USB recipe reading and uploading remain unverified and are not implemented.** Camera testing is deferred until the owner has an untouched official settings backup. No camera settings have been changed.

## Build and run

Requires macOS 14+ and Xcode 15 / Swift 5.9+.

```sh
swift test
swift run RecipeManager
```

To create an ad-hoc signed, sandboxed application bundle:

```sh
Scripts/package-app.sh
unzip "dist/Fujifilm-Recipe-Manager-macOS-$(uname -m).zip" -d /tmp/RecipeManagerPreview
open "/tmp/RecipeManagerPreview/Fujifilm Recipe Manager.app"
```

The script signs in a temporary folder and outputs a ZIP, avoiding cloud-sync metadata being attached to a loose bundle before archiving. Extract into a local folder (such as Downloads) to run it. The bundle includes USB and user-selected-file entitlements, with no network entitlements. It is a development build, not notarized or signed for public distribution. Builds target the current host architecture. Open `Package.swift` in Xcode to inspect the source.

## Library

Use **New recipe**, enter the recipe and attribution, then **Save recipe**. Blank settings remain unspecified; numbers use display units rather than PTP values. No recipe is assigned to or uploaded to a camera bank. Unsupported/imported fields are retained. Use your camera menus for manual entry.

The **Library** menu imports or exports versioned Recipe Manager JSON. Import adds all entries or fails without changes if IDs or library metadata conflict. Exports are local recipe documents, **not camera settings backups**. See [document format and storage](docs/LIBRARY_FORMAT.md) for details, migration and file recovery.

## Camera inspector

Opening the inspector does not start scanning. A future owner-led test requires an official backup acknowledgement, then an explicit scan and identity request. Only local Fujifilm USB devices are listed. The sole PTP command is GetDeviceInfo; the serial number is discarded. There is no bank-selector, capture, tether-enable, restore or settings-write API. No hardware compatibility is claimed from parser tests or bundle signing.

## Documentation

- [Phase 1 feasibility and evidence](docs/FEASIBILITY.md)
- [Open-source and licence review](docs/LICENSING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Backup safety](docs/SAFETY.md)
- [Phase boundaries](docs/ROADMAP.md)
- [Phase 2 validation and limitations](docs/PHASE2_VALIDATION.md)

The initial repository contained only a short README. The implementation has no third-party code or dependencies. A project distribution licence remains an owner decision; public visibility alone does not select one. Potential iPhone support can reuse domain documents but still needs a separate app and transport investigation.

PRs remain subject to owner approval before merging. Phase 2 does not authorize camera writes, selector changes or restoration experiments.
