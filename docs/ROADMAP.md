# Phase boundaries and acceptance

## Phase 1 deliverables

- Inspected initial repository: README only at `e4dd976`; no existing app or licence.
- Researched official X-M5 backup mode, C1–C4 and dial behavior, FujiSync, community PTP notes, libgphoto2, libpict, libfuji and Apple ImageCaptureCore.
- Recorded evidence strength, X-M5 unknowns, selector-write risk, backup limitations and licence obligations.
- Established an original dependency-free Swift package, SwiftUI shell, shared scope module, macOS build CI and documentation.
- Camera access remains absent. No camera settings were changed.
- Work is proposed on `phase1/research-and-project-initialisation` in an unmerged PR.

Build and delivery results are reported in the PR. No hardware or restoration validation is part of this phase.

## Proposed Phase 2 — requires owner approval

Build an offline recipe library with explicit import/export and user-entered recipe metadata. Add synthetic fixtures for document migrations and unknown-field preservation. Separately develop a strict read-only device inspector after reviewing the safety plan and obtaining the required camera access/mode permissions. Test macOS packaging and sandbox permissions.

Expected outputs: local library usable without camera or internet, identity/firmware diagnostics, documented transport visibility and supported read evidence. If bank enumeration needs selector writes, record it as blocked pending a separate approved state-changing experiment. Do not expand Phase 2 approval into blanket upload or restore authorization.

## Later experimental USB milestone — not authorized

Only after a validated original backup and agreed recovery route: investigate selector behavior on X-M5, confirm C1–C4 mapping and still/movie safety, validate individual parameter encodings/ranges and names, then one-bank write/readback/reconnect/recovery. Expand coverage only on evidence, keyed to model and firmware. Keep writes unavailable for unverified profiles.

If USB remains unsupported, the offline library and manual camera-entry workflow remain useful. Do not work around unsupported USB by editing opaque backup blobs or deploying firmware modifications.

## Owner gate

Review the Phase 1 PR and findings before starting Phase 2. No merge, Phase 2 implementation, camera test or write experiment is authorized by this Phase 1 task.
