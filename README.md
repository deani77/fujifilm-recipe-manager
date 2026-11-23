# Fujifilm Recipe Manager

Offline-first recipe manager planned for macOS using Swift and SwiftUI, initially targeting the Fujifilm X-M5. Shared domain code may support an iPhone app later; iPhone USB support is not established.

**Phase 1: research and project initialisation. USB C1–C4 reading, uploading, backup and restoration have not been verified on an X-M5.** The current app is an informational shell with no camera, network, persistence or recipe-editing implementation.

## Build

Requires macOS 14 or later and Xcode 15 / Swift 5.9 or later.

```sh
swift build
swift run RecipeManager
```

Open `Package.swift` in Xcode to inspect the package. This is a Swift package executable, not a signed, sandboxed application bundle or distributable installer. Packaging, entitlements and device permissions will need their own validation.

## Documentation

- [Feasibility and evidence](docs/FEASIBILITY.md)
- [Open-source and licence review](docs/LICENSING.md)
- [Architecture and project structure](docs/ARCHITECTURE.md)
- [Backup safety and future validation](docs/SAFETY.md)
- [Phase boundaries and acceptance](docs/ROADMAP.md)

The repository was inspected at initial commit `e4dd976`: only a brief README existed, with no app, build setup, licence or repository agent instructions. Phase 1 adds an original project shell without third-party dependencies or copied implementation code. A project distribution licence remains an owner decision.

No camera was accessed or modified in Phase 1. Do not run upstream camera tools as a substitute for the gated validation plan. In particular, some routines labelled “read” write a slot selector.

Phase 2 requires explicit owner approval. The Phase 1 PR must not be merged without approval.
