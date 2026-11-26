# Backup and validation safety

## Phase 1 record

Research used repository source and public documentation only. No camera enumeration, USB session, protocol command, application backup, firmware update, selector change, settings change or restoration was performed. There is no backup from the user's camera in this repository and no claim that restoration has been tested.

## Proposed read-only investigation after approval

1. Record exact model and firmware, OS, cable, current USB mode and bank assignment. Ask the owner before any camera-menu mode change; do not silently enable backup/tether mode.
2. Have the owner create an original backup through the official X-M5-compatible TETHER APP workflow. Store it privately outside Git, keep an untouched second copy, record SHA-256/size and the tool version. Record bank names and visible values, still/movie assignments, dial positions and custom WB information separately. Do not call a recipe-only export a full backup.
3. Validate the future app bundle's permissions, USB visibility and exclusive session ownership with other camera apps closed. Discovery must not enable tethering, capture a photo or perform vendor setup writes automatically.
4. Source-review and allowlist the minimum identity/descriptor/value reads; validate returned lengths/types, serialize transactions, set timeouts, stop on malformed data or disconnection, and redact serial numbers from shared logs. Do not run generic upstream probes/bench tools or sweep unknown vendor codes.
5. No SetDevicePropValue, slot selection, SendObject, capture, restore, firmware operations or data-out commands in strict read-only work. If a requested observation requires a selector write, record that limitation and stop that observation. Session open/close affects connection state; it is not permission to change camera settings.
6. Store raw responses and identity locally. A missing advertised property is unresolved support, not permission to probe writes. Distinguish currently selected bank values from live shooting state and from a complete C1–C4 archive.

An official backup file is a prerequisite, not proof of recoverability. Read-only development can proceed while recovery remains untested; write experiments cannot.

## Separate gate for any future state-changing test

A later explicitly authorized test must establish backup applicability to this body/firmware and a recovery procedure before any recipe overwrite. An actual restore test is itself a camera modification and requires its own authorization; never perform it just to “check the backup.” Do not promise automatic rollback or atomic writes.

Before selector or recipe writes, agree on one expendable **still** bank, preserve its type and all unrelated fields, record the selector/current bank when readable, and present the exact intended diff. Limit targets to C1–C4. Do not guess a selector value or use C5–C7. Unknown fields and unsupported combinations must remain untouched.

Start with one mapped change; check per-property responses, read back and verify persistence after a controlled reconnect/power cycle. Inspect all banks and unrelated settings for collateral changes. An OK response alone is not success. Stop on any uncertain outcome; preserve the original backup and logs, prevent further queued writes, and use only the agreed recovery procedure with explicit user action. Retrying a multi-field write can compound partial state.

When recovery is authorized, restore from the original unedited backup through the validated official route and compare all recorded bank values/assignments, with reconnect verification. Record exclusions and anything that cannot be verified. Firmware changes invalidate the previous validation record until retested.

## Data handling

Camera backups, raw dumps, photos, serials and local recipes stay outside source control. `.gitignore` provides local-data/backups/captures exclusions and common camera-file exclusions; it is not a substitute for reviewing staged files. Only synthetic, redacted fixtures may be committed later. The app must remain functional offline and must not upload diagnostics automatically.

## Phase 2 status

The owner approved software development but deferred camera testing until an official backup exists. The identity inspector is implemented and compiled; no discovery or USB session was executed. Opening its sheet does not start discovery. Its only raw command is GetDeviceInfo with no data-out payload; it cannot select banks or write settings. No camera-backup archive or restore feature is included.

## Owner-led import — 27 November 2026

The owner confirmed an untouched official backup and authorized trying camera-to-app recipe retrieval, including the explained selector changes. The manual utility read C1–C4 and restored the original selector with read-back verification. No recipe-setting or backup restoration test was authorized or performed. This supersedes the earlier deferred status for this bounded import only. See CAMERA_IMPORT_VALIDATION.md; sending recipes to the camera remains outside the implemented scope.
