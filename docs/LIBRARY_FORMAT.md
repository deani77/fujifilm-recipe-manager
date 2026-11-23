# Recipe documents and storage

## JSON format, version 1

```json
{
  "schemaVersion": 1,
  "recipes": [{
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Example format only",
    "author": "Recipe author",
    "source": "Source or attribution",
    "notes": "Manual camera-entry notes",
    "parameters": { "filmSimulation": "Classic Chrome", "highlight": -1.5 }
  }]
}
```

Required: integer schemaVersion 1, recipes array, and a unique UUID, nonblank name and parameters object for each entry. Document size is limited to 5 MiB. Version 0 is a defined legacy fixture format with `settings` instead of `parameters`; it migrates to version 1 on the next save/export. Missing versions and future schema versions are rejected. No other third-party recipe format is claimed compatible.

Settings are optional. Absence is distinct from zero or Off. Numeric values use display units and Decimal encoding, including half-step tones. The editor validates changed numeric fields without silently clamping. It uses a dot decimal separator. Text parameters accept user-entered names and notes; they do not establish whether a camera supports that value or combination. Fields of an unknown JSON type are retained rather than coerced by the editor.

Unknown keys at document, recipe and parameter levels survive editing and export as semantic JSON values, including nested structures. Whitespace, key ordering and numeric spelling may change. JSON numbers must be representable by Foundation Decimal; this is not an arbitrary-precision archival format or camera-backup codec. Do not import raw camera backups.

Import merges the whole document in one save. Duplicate recipe UUIDs or unequal values for the same top-level metadata key reject the entire import. No existing entries are overwritten and no entries are silently skipped. Export a single recipe or the entire library. Exporting a single recipe retains library-level metadata, including unknown fields; inspect sensitive metadata before sharing a file.

## Persistence

For the Swift package executable, the default file is `~/Library/Application Support/FujifilmRecipeManager/library.json`. A sandboxed app uses the equivalent Application Support directory inside its container (`com.deani77.FujifilmRecipeManager`). These stores are separate; use explicit export/import to move documents between them.

Each save validates and encodes the candidate before writing, acquires a nonblocking local file lock, and compares current bytes to those last loaded. A conflicting instance or external edit fails rather than losing changes. Successful updates write the previous bytes to `library.json.previous` and atomically replace `library.json`. The first save has no previous file. The previous copy rotates on each save; it is not an unlimited undo history or independent backup.

If loading fails, editing/import/export are disabled; the original file is not replaced with an empty library. A save failure leaves the in-memory library unchanged and the editor draft open. A conflicting save requires reloading from disk; preserve any draft text before closing/reloading. File locks coordinate this app's instances; external editors need not honor them. Atomic replacement is not a guarantee against storage-device failure or all external writer races.

For recovery, quit the app, make a separate copy of the library and previous file, inspect/validate the candidate copy, and restore it manually only when ready. Do not delete a corrupt file to dismiss an error before preserving it. Normal deletion asks for confirmation; export your library periodically to retain an independent copy.

For development, `RECIPE_MANAGER_LIBRARY_PATH` can point to an isolated test file. Sandboxed builds can access it only if sandbox permissions allow it. Never commit real library documents, serials or camera backups.
