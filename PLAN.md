# Zelda Mac Studio — Autonomous implementation plan

**How Codex uses this file:** This is the starting plan, **not a mandate to stop at each phase**. Audit/reorder as engineering evidence warrants. Execute the milestones in one session where feasible. Mark a box complete only with a linked commit or test evidence; record blockers and continue independent tasks. Add dated notes below.

## 0. Readiness and safeguards
- [x] Read `PRD.md` and `AGENTS.md`; inspect repo/toolchain; record OS, Xcode, Swift, git, SDK and available build routes.
- [x] Create repo-safe `.gitignore`; ensure no games, keys, firmware, real saves, generated binaries or user library files can enter Git.
- [x] Verify no current user files are modified. Create synthetic fixtures for all tests.
- **Gate:** Know whether Sonoma build is possible; if no compatible toolchain, implement source/tests as far as possible and state what can't be verified.

## 1. Application foundation — P0
- [x] Build native SwiftUI macOS app with real `.app` output and navigation.
- [x] Implement domain types, storage repository, schema 1 and filesystem layout; reject unsupported schemas. No legacy schema exists to migrate.
- [x] Provide useful empty states, readiness/diagnostics screen, folder pickers and error states.
- [x] Add unit test target and reproducible build/test commands.
- **Gate:** app builds and launches; restart preserves sample local data.

## 2. Environments, isolation and snapshots — P0
- [x] Create/rename/archive/delete environment; clone deep immutable configuration and independent mutable saves.
- [x] Environment comparison and per-environment mod lists/order.
- [x] Create/list/restore immutable snapshots with verification and transactional rollback.
- [x] Block changes while a runtime environment is active; prevent save sharing.
- **Gate:** fixture test proves clone's save/mod changes do not alter origin; revert restores checksums; interruption leaves recoverable state.

## 3. Mod import, planning and diagnostics — P0
- [x] Implement secure ZIP/folder importer and immutable mod library with hashes, metadata and provenance.
- [x] Classify RomFS/ExeFS/unknown and display game version/backend capabilities honestly.
- [x] Implement per-environment enable/disable/load order, deterministic deployment plan, same-path conflict detection and dry-run diff.
- [x] Implement staged synthetic deployment, undo, readable logs/statuses and user-facing conflict handling.
- **Gate:** safe import, malicious ZIP rejection, deterministic overlay, conflict warning and clean disabling/revert via fixtures.

## 4. Portable library, manual cross-Mac transfer — P1
- [x] User-selectable folder with security-scoped access handling as appropriate.
- [x] Export/import immutable versioned manifests, mod packages, environment data and snapshot lineage.
- [x] Atomic commit markers/checksum validation, missing/cloud-placeholder handling and conflict branches.
- [x] Keep machine-local runtime/caches/keys/live saves excluded.
- **Gate:** round-trip between two simulated machines; interruption/corruption caught; divergent changes preserved without silent overwrite.

## 5. Runtime and mod merging research/integration — P1
- [x] Evaluate current MacNativeGames requirements, actual mod workflow, limitations and license; note native runtime deferred until macOS 26.
- [x] Evaluate current macOS Switch emulator candidates and viable isolated configuration/save launching.
- [x] Evaluate TKMM as reusable library/CLI; document licensing and integration evidence.
- [x] Implement one or more **actually working, testable** adapters/deployers when prerequisites permit; otherwise implement explicit capability/readiness and disabled actions (not pretend functionality).
- [ ] Add supported backend graphics presets only after verifying real supported setting names.
- **Gate:** fixture-backed adapter integration; real runtime/game test only if clean game and OS are available. Do not claim game success otherwise.

## 6. UX, packaging and quality — P0/P1
- [ ] Complete visual/interactive QA for the implemented `Clone & Experiment`, mod, snapshot and readiness views (UI automation transport blocked after initial launch inspection).
- [ ] Complete keyboard/trackpad/VoiceOver acceptance for implemented native controls and progress/error states (full interaction not verified).
- [x] Build release-ish development app, run unit/integration tests and perform a UI smoke test.
- [x] Document installation, use, missing prerequisites, architecture, safety, and limits in README/DECISIONS.
- [x] Audit git status/history for secret/game/save files and accidental scope changes.
- **Gate:** trustworthy app, test report and functional status matrix.

## Deferred by design (do not block completion)
- [ ] End-to-end native TOTK on macOS 26 with a **clean validated base game** and working keys/fonts.
- [ ] Verified sophisticated real-game mods / resource merges / in-game behavior.
- [ ] Automatic cloud provider-independent synchronization across MacBook Pro and Mac Studio.
- [ ] GameBanana in-app browser, additional games including BOTW, controller navigation in manager.

## Progress / evidence log

_Codex: append dated notes with completed steps, relevant commit hashes, build and test commands/results, architectural decisions, blockers, and any user permission request. Do not pre-check boxes._

## 2026-10-21 — initial audit and design
- Read all three root documents and the complete attached implementation request.
- Read-only audit: macOS 14.6.1 (23G93), Xcode 16.2 (16C5032a), Swift 6.0.3, macOS SDK 15.2, Git 2.39.5, Homebrew 6.0.18. Compatible build route exists; nothing installed or reconfigured. Repository initially contained only the three untracked instruction documents; no prior commits.
- No game search repeated and no game/key/save files accessed. `.gitignore` excludes private inputs and generated outputs.
- Chose an immutable revision store with atomic catalog commits, strict bounded ZIP import using system zlib, and a runtime-independent laboratory deployer. See DECISIONS.md.
- Foundation evidence: `swift test --scratch-path .build --cache-path .build/cache` built the core and SwiftUI executable; 2 tests passed (schema round-trip and unsafe paths). Initial sandbox attempt could not write the compiler cache; approved build access resolved it. No security controls disabled.

## 2026-10-21 — isolated environments and snapshots
- Foundation committed as `b0e4aeb`.
- Implemented persistent create/rename/archive/recoverable Trash, independent clone/save copies, immutable snapshot checksums, transactional restore, pre-restore recovery snapshot and active-runtime mutation guards.
- `swift test --scratch-path .build --cache-path .build/cache`: **7 tests passed**, including clone/save isolation, persistence/reopen, fresh-save clone, recoverable deletion, corrupt snapshot rejection, running-environment guards, schema rejection and injected restore-commit failure. Fixed a real `/var` vs `/private/var` canonical-path bug exposed by the first integration run.

## 2026-10-21 — secure mod workflows
- Implemented folder and stored/deflate ZIP import, immutable original ZIP retention, content identity, duplicate detection, RomFS/ExeFS/cheats/patches classification, independent selection/order, path conflict blocking, deterministic overlay diff, verified staged deployment and automatic recovery snapshots.
- Limits: 256 MiB compressed archive, 128 MiB per ZIP entry, 1 GiB expanded tree, 20,000 entries. Reject traversal, absolute/backslash paths, links, private input extensions, duplicate/case-colliding paths, bad CRC, truncated/unsupported archives, and expansion over quota. No downloaded content is executed.
- Evidence: all **18 tests passed**, including 5 ModTests covering import/dedup, stored/deflate ZIP, malicious paths, links, quotas, CRC, truncated data, unknown/ExeFS blocking, conflicting paths, deploy/disable/revert, clone isolation and injected deployment failure. SwiftUI executable also compiled.

## 2026-10-21 — portable transfer and runtime boundaries
- Manual Publish/Pull implemented with immutable UUID publications, SHA-256 manifests, completion markers, staging, source re-verification and one catalog commit. Existing environment IDs become independent imported branches; no timestamp overwrite policy. Save snapshots are opt-in and never live-runtime sync.
- Three PortableTests pass: round-trip/divergent saves retained; missing completion marker, corrupted payload and interrupted commit rejected; save-excluded default export and overlapping workspace/portable paths handled. Fixed empty revision-directory preservation discovered by the test suite.
- Runtime readiness/protocol and owned-process registry implemented; 3 RuntimeTests pass for fail-closed launch, actual process monitor/terminate and allow-listed diagnostics.
- Upstream evidence and precise integration limits recorded in Docs/UPSTREAM.md. Tkmm.CLI does exist; net10.0 projects and TkSharp resource merger are research leads, not integrated claims. No dotnet executable found on PATH. No dependencies installed.
- `swift test --scratch-path .build --cache-path .build/cache`: 18 tests, 0 failures. Xcode Release build also succeeded using the local package and an ad-hoc development signature.


## 2026-10-21 — native UI, packaging and final hardening
- Native navigation and connected actions implemented for Library, Environments, Mods, Snapshots, Runtimes, Settings & Diagnostics. Includes initial setup, security-scoped folder/reference bookmarks, synthetic demo, Clone & Experiment, import/drop, reorder/toggle, plan preview, confirmed restore/Trash, comparisons, compatibility notes, explicit save-folder copy, Publish/Pull and sanitized-report preview/export. Play is disabled with reasons.
- Added a reproducible Xcode project, shared scheme, app metadata, original generated AppKit icon and build script. Release `.app` builds with Xcode 16.2 and an ad-hoc local signature; `codesign --verify --deep --strict` passed. Info.plist and project plist lint passed.
- Actual smoke launch: `open -n build/DerivedData/Build/Products/Release/ZeldaMacStudio.app --args --workspace <project>/build/SmokeWorkspace`. Computer-use accessibility inspection confirmed the native titled window, all six navigation rows, empty adventure list, Create Environment button and Workspace ready status. Subsequent UI actions failed with `Sky Computer Use native pipe closed before response`; reconnect/reset also failed. Full interactive click-through, screenshot/layout QA and folder-picker acceptance remain **Untested**, not marked passed.
- Added stale deployment-preview rejection, managed-path symlink defense, concurrent catalog reload tests, allow-listed package export, hard-link and cross-package case-collision tests, portable mod round-trip and explicit save-folder copy/restore. Save source checksum remains unchanged in fixtures. Added conflicting provider-file rejection and catalog/manifest size bounds.
- Latest full suite: **24 XCTest cases, 0 failures**. Tests use generated synthetic assets/saves and disposable local roots only. No game search, game launch, actual game/save/key access, dependency installation, OS/permission change or network upload occurred.
- Checked milestone boxes mean implementation plus the specific evidence above, not real-game acceptance. Schema 1 rejects unsupported versions; legacy migration has no input schema yet. Metadata stays unknown; live runtime/merge/graphics work remains blocked. Read README status table and Docs/VERIFICATION.md for exact limits.
- Next implementation step: complete native interactive acceptance when the UI connection is available, then pin a runtime and verify an isolated launch contract using a clean personal game dump before enabling any live deployment or Play. Do not repair/use the known damaged NSP.

- Final verification after sync-conflict and size-limit hardening: `swift test --scratch-path .build --cache-path .build/cache` **24 passed / 0 failed**; Xcode Release **BUILD SUCCEEDED**; final bundle signature verification passed. Initial tracked-file audit passed; final staged audit is performed before the delivery commit. Raw build/test logs remain ignored under `build/`.
- Final staged audit: `python3 Scripts/audit_tracked.py` passed for **35 tracked/staged files**; `git diff --cached --check` passed. No prohibited private/build artifacts detected. Hardening milestone committed as `24e1021`; native UI/packaging/documentation is the final delivery commit. No push performed.
