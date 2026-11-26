# Architecture and foundation

## Current structure

```text
Package.swift                     macOS 14+, Swift 5.9+, no dependencies
Sources/RecipeCore/                platform-neutral product scope
Sources/RecipeManagerApp/          SwiftUI informational shell
.github/workflows/build.yml       macOS package build on pushes and PRs
docs/                             research, licensing, safety and roadmap
```

The shell shows the target camera, four bank labels and unverified USB status. It deliberately has no connection button or upload control. There is no PTP implementation, device discovery, storage, network client or recipe editor. A package executable establishes compilation without committing to an Xcode project generator, signing identity or installer. Local build success does not establish packaged app or camera behavior.

## Proposed later boundaries (not implemented)

- **RecipeCore**: versioned recipe documents with source/author metadata, explicit units and optional/unknown fields. Preserve decimal tone values and distinguish absence from zero. Model still/movie bank assignment separately from recipe parameters. Avoid treating seven-bank upstream models as X-M5 capabilities.
- **Local library**: Application Support storage with atomic writes, migrations and explicit import/export. No account, cloud sync, analytics or internet requirement. Back up library documents separately from original camera backups.
- **Camera inspection**: macOS ImageCaptureCore adapter with serialized session ownership and bounded diagnostics. A strict read-only capability surface must not expose generic write/data-out operations. Allowlist operations after source review; unknown operations fail closed. Do not copy upstream session initialization unchecked.
- **Backup archive**: preserve original bytes with checksum, byte count, model, firmware, capture time, source tool and verification state. A checksum proves file integrity, not restoration compatibility or completeness.
- **Future writer**: distinct module, absent now. Require verified device profile, validated target bank, backup preflight, proposed diff, explicit user action, per-field outcomes and persistent readback. No silent upload or automatic restore on reconnect.

Do not add generic “read all slots” to the read-only interface if it changes `0xD18C`. Selector operations need a separate authorization boundary even if their purpose is reading. Keep local library features usable when the camera is unsupported or disconnected.

Potential iPhone support should reuse domain documents and validation rules. App lifecycle, document access, discovery, USB permissions and camera transport remain separate work. Do not promise an iOS USB feature based on the Mac scaffold.
