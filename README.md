# Zelda Mac Studio

A native Sonoma app for independent Zelda environments, mod experiments and reversible checkpoints. **The manager works locally; game launch and live-runtime deployment are unavailable in this release.** No game content, keys, firmware or emulator is included.

## Build and open

Verified on Apple Silicon, macOS **14.6.1**, **Xcode 16.2**, Swift **6.0.3**, macOS SDK **15.2**. No Homebrew packages or downloaded dependencies are required.

From the project root:

```sh
swift test --scratch-path .build --cache-path .build/cache
bash Scripts/build.sh
open build/DerivedData/Build/Products/Release/ZeldaMacStudio.app
```

The built bundle is `build/DerivedData/Build/Products/Release/ZeldaMacStudio.app`. Open `ZeldaMacStudio.xcodeproj`, select the **ZeldaMacStudio** scheme and My Mac, then Build/Run. Core tests use Swift Package Manager; they are not a UI-test target in the Xcode app scheme. `Package.swift` can also be opened in Xcode for package tests.

The app is locally ad-hoc signed, not notarized for distribution. It launches normally on this build machine. No Apple signing credentials or Gatekeeper bypass is needed for the verified local build. You may copy this newly built app to a user-owned Applications folder yourself; no installation into an existing app is performed by the build script.

## First experiment

1. Choose **Use Application Support** or select an empty/existing Studio workspace. Keep the working workspace local, separate from cloud-synced publication folders.
2. Open **Library → Create Synthetic Demo** for a generated save and sample asset mod containing no game data. Or create your own empty environment.
3. Select the adventure and choose **Clone & Experiment**. Choose whether to copy its managed saves. The clone has separate save and overlay files.
4. Enable the sample mod in the clone. **Try a Mod** accepts a ZIP or folder. The Mods page also accepts a dropped file/folder URL.
5. **Preview Deployment** shows added, changed and removed paths. Confirm to build a laboratory overlay. Each deployment records a recovery snapshot. This does not install into a running game.
6. Disable a mod and deploy again to remove its files, or choose **Revert** on a snapshot. Restore validates hashes and preserves the previous revision. Compare environments/snapshots to inspect mod order, versions and changed save/overlay hashes.
7. **Copy Save Folder** explicitly copies a selected folder into a new managed revision. It never edits the source and automatically snapshots the previous managed saves. Real-game compatibility is unverified; no original saves were used in development.
8. Rename/archive via the environment menu. **Move to Trash** is recoverable in Settings & Diagnostics. No permanent deletion or automatic pruning is implemented.

Unknown formats and game versions stay unknown. ExeFS/code patches and cheats are blocked by this deployer. Two enabled mods changing the same normalized path stop deployment, including case-only collisions. Disable a conflicting mod and preview again; load order does not perform semantic merging.

## Portable library

Select a separate folder under Library or Settings. **Publish New Version** creates a new UUID `.zmslibrary` directory. The default excludes saves. Explicitly enable immutable managed save checkpoints only for local transfer of private saves. The app has no network/upload or cloud-provider API.

Copy a complete publication locally to another Mac and choose **Pull Publication**. Every payload file and the completion marker is verified before committing. A matching local environment ID becomes a separate imported branch; neither save history is overwritten. Repeated pulls deliberately create additional branches rather than guessing which history to discard. Incomplete downloads, extra conflict files, missing files, corrupt hashes and unsupported schemas fail closed.

Exports include selected mod contents/original ZIPs, ordered configuration, notes, overlay revisions and snapshots. They exclude machine-local bookmarks, game inputs, keys, firmware, runtime builds, caches and active runtime saves. Notes are exported verbatim: keep private paths or secrets out of your notes. Folder/file-provider round-trips are tested with local fixtures; actual Dropbox/iCloud/Synology behavior has not been tested. Automatic sync is deferred.

## Readiness and limits

| Feature | Status | Evidence / limitation |
|---|---|---|
| SwiftUI app, Xcode project, Release bundle | Working | Compiles and launches on Sonoma; native empty-state window observed |
| Persistent create/rename/archive/Trash/recover | Working | Catalog/reopen and recovery tests |
| Clone & Experiment, independent saves/overlays | Working | Source hashes unchanged through clone edits/deletion |
| ZIP/folder import, hashes, dedup, attack rejection | Working | Stored/deflate, path/link/CRC/quota tests |
| Ordered selection, conflicts, preview, laboratory deployment | Working | Enable/deploy/disable/restore and failure rollback tests |
| Snapshot/restore and save-folder copy | Working | Hash verification, pre-operation snapshots, source preservation |
| Environment/snapshot comparison and notes | Working | Service implementation; full UI click-through not verified |
| Manual portable Publish/Pull | Working | Independent roots, divergent branches, corrupt/incomplete/interrupted imports tested |
| Runtime readiness and process registry | Partial | Guarded adapters; owned system process lifecycle tested; no game execution |
| Machine-local registration bookmarks | Partial | Selection/reference persistence implemented; content integrity validation not integrated |
| Metadata/version/runtime compatibility matrix | Partial | Format classification and unknown statuses; no trusted metadata resolver |
| Sanitized diagnostics | Working | Allow-list report excludes names, notes, paths, keys and raw logs |
| Native TOTK / emulator launch / live deployment | Blocked | Damaged inventoried base; native OS requirement; isolated adapter contract unverified |
| TKMM resource merging / graphics presets | Blocked | CLI/library researched; .NET 10 integration and backend settings unverified |
| Full GUI workflow / provider-specific transfer | Untested | UI connection failed after successful window inspection; local core fixtures passed |
| Actual in-game mod and save compatibility | Untested | No clean game/runtime acceptance test performed |

### Import and storage bounds

- ZIP: single-disk stored or deflate, UTF-8-decodable names; no encryption, ZIP64 or other compression formats. 256 MiB compressed, 128 MiB per entry, 1 GiB expansion, 20,000 entries. Folder/tree copies also have a 1 GiB / 20,000-entry ceiling; portable tree verification counts bundled original archives too.
- Symlinks, hard links, special files, unsafe paths and known private-input filenames/extensions are rejected. Imported scripts/binaries are never executed. Only recognized lowercase `romfs` content is deployed.
- Schema 1 catalogs/manifests have a 16 MiB ceiling. Unsupported schemas are rejected, not reset. No legacy migration exists because this is the first schema.
- Revisions are immutable through the app API and checked by manifests when restored/deployed. They are not a tamper-proof vault against the account owner. Do not manually edit workspace contents. Workspace should not be writable by untrusted processes.
- Atomic catalog commits protect against process interruption; power-loss durability, hostile concurrent filesystem mutation and disk-full fault behavior have not been exhaustively tested. Previous revisions and orphaned stages are retained; there is no garbage collector, so storage grows.
- Managed-file changes are blocked when the injected runtime monitor reports activity; the app conservatively checks common runtime app names. Since live launching is disabled, no runtime is pointed at these revisions. Unknown externally launched runtimes cannot be guaranteed detectable.

## Architecture and evidence

See [DECISIONS.md](DECISIONS.md), [PLAN.md](PLAN.md), [portable schema](Docs/PORTABLE_FORMAT.md), [upstream research](Docs/UPSTREAM.md), and [verification report](Docs/VERIFICATION.md).

The core is Foundation/CryptoKit with a small system-zlib bridge. UI operations use a serial worker queue and publish value snapshots on the main thread. Filesystem changes are staged, verified and committed through one atomic catalog replacement under a filesystem lock.

Run `python3 Scripts/audit_tracked.py` before committing or pushing. No push or private-content upload is part of the build.

## Next integration steps

1. Finish interactive UI acceptance on this build; automated core coverage does not replace picker, accessibility and layout checks.
2. With a clean personal dump, choose a pinned runtime and verify independent save/mod/config roots, version-specific arguments and process behavior. Add adapter fixtures before enabling Play. Do not reuse the damaged NSP or global live saves.
3. Assess the Tkmm.CLI command contract and complete dependency/license review in an authorized .NET environment; integrate resource merging only with tests against supported formats.
4. Test full local transfer between two Macs and actual file-provider conflict behavior. Add retention/pruning only with a reviewed recovery policy.
