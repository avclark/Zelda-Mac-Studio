# Portable format and transaction contract (schema 1)

A publication is a UUID-named `.zmslibrary` directory:

```
manifest.json
COMPLETE
payload/
  packages/<content-sha256>/content/<original relative paths>
  packages/<content-sha256>/original.zip  (ZIP imports only)
  revisions/<revision-uuid>/overlay/romfs/<asset paths>
  revisions/<revision-uuid>/saves/<save paths>  (explicit opt-in only)
```

`manifest.json` contains schema=1, publication UUID, environment definition, package metadata, snapshot records and a relative-file SHA-256 map covering the entire payload. The environment has stable UUID/game ID, declared game version, backend, revision, parent lineage, ordered mod IDs, archive/Trash flags, deployment generation, notes and creation timestamp. No machine-local path or key contents belongs in this schema. User-authored notes are not redacted, and should not contain private paths or secrets.

Mod identity is SHA-256 of canonical sorted-key JSON for its relative-path → SHA-256 map. Package metadata includes detected formats, import type, unknown version/compatibility and original archive hash when present. File names are normalized for collision detection; original spelling is retained. No semantic merger is implied.

`COMPLETE` contains the hexadecimal SHA-256 of the exact manifest bytes. Writers stage in a unique `.partial-*` sibling, write/verify payload, write the manifest and marker, then promote the directory by rename. Readers reject unexpected publication-root files (including provider conflict copies), missing/bad marker, unsupported schema, links, unsafe paths, missing/extra payload files and bad hashes. Checksums provide integrity, not publisher authentication.

Each snapshot includes its saved environment definition and a manifest of that revision's overlay/save files. If saves are excluded on export, snapshot manifests are recalculated for the exported representation. Empty revision directories are preserved. Pull copies and verifies in local staging, validates package IDs and snapshots, copies each revision to a fresh local revision UUID, then atomically updates the local catalog. If the environment UUID exists, a new local environment UUID branches from it and both histories remain. Duplicate pulls intentionally preserve separate branches; publication deduplication is not implemented.

The working catalog (`catalog.json`, schema 1) references revision directories under `revisions/<environment-uuid>/<revision-uuid>`. Each operation obtains a nonblocking exclusive file lock, reloads current state, writes an independent revision, verifies it, and atomically replaces the catalog. Failure before replacement leaves the old catalog active. Snapshots retain revisions; Trash only changes a flag. Orphaned stages/revisions are retained. There is no destructive automatic recovery or garbage collection.

Concurrency is cooperative between Studio instances. The app does not protect against arbitrary malicious processes running as the same user. An unsupported/corrupt catalog fails closed rather than being silently migrated/reset. First-schema code has no legacy migration path.
