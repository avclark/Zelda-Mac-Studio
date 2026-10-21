# Zelda Mac Studio — Autonomous implementation plan

**How Codex uses this file:** This is the starting plan, **not a mandate to stop at each phase**. Audit/reorder as engineering evidence warrants. Execute the milestones in one session where feasible. Mark a box complete only with a linked commit or test evidence; record blockers and continue independent tasks. Add dated notes below.

## 0. Readiness and safeguards
- [ ] Read `PRD.md` and `AGENTS.md`; inspect repo/toolchain; record OS, Xcode, Swift, git, SDK and available build routes.
- [ ] Create repo-safe `.gitignore`; ensure no games, keys, firmware, real saves, generated binaries or user library files can enter Git.
- [ ] Verify no current user files are modified. Create synthetic fixtures for all tests.
- **Gate:** Know whether Sonoma build is possible; if no compatible toolchain, implement source/tests as far as possible and state what can't be verified.

## 1. Application foundation — P0
- [ ] Build native SwiftUI macOS app with real `.app` output and navigation.
- [ ] Implement domain types, storage repository, schema/versioning, migrations and filesystem layout.
- [ ] Provide useful empty states, readiness/diagnostics screen, folder pickers and error states.
- [ ] Add unit test target and reproducible build/test commands.
- **Gate:** app builds and launches; restart preserves sample local data.

## 2. Environments, isolation and snapshots — P0
- [ ] Create/rename/archive/delete environment; clone deep immutable configuration and independent mutable saves.
- [ ] Environment comparison and per-environment mod lists/order.
- [ ] Create/list/restore immutable snapshots with verification and transactional rollback.
- [ ] Block changes while a runtime environment is active; prevent save sharing.
- **Gate:** fixture test proves clone's save/mod changes do not alter origin; revert restores checksums; interruption leaves recoverable state.

## 3. Mod import, planning and diagnostics — P0
- [ ] Implement secure ZIP/folder importer and immutable mod library with hashes, metadata and provenance.
- [ ] Classify RomFS/ExeFS/unknown and display game version/backend capabilities honestly.
- [ ] Implement per-environment enable/disable/load order, deterministic deployment plan, same-path conflict detection and dry-run diff.
- [ ] Implement staged synthetic deployment, undo, readable logs/statuses and user-facing conflict handling.
- **Gate:** safe import, malicious ZIP rejection, deterministic overlay, conflict warning and clean disabling/revert via fixtures.

## 4. Portable library, manual cross-Mac transfer — P1
- [ ] User-selectable folder with security-scoped access handling as appropriate.
- [ ] Export/import immutable versioned manifests, mod packages, environment data and snapshot lineage.
- [ ] Atomic commit markers/checksum validation, missing/cloud-placeholder handling and conflict branches.
- [ ] Keep machine-local runtime/caches/keys/live saves excluded.
- **Gate:** round-trip between two simulated machines; interruption/corruption caught; divergent changes preserved without silent overwrite.

## 5. Runtime and mod merging research/integration — P1
- [ ] Evaluate current MacNativeGames requirements, actual mod workflow, limitations and license; note native runtime deferred until macOS 26.
- [ ] Evaluate current macOS Switch emulator candidates and viable isolated configuration/save launching.
- [ ] Evaluate TKMM as reusable library/CLI; document licensing and integration evidence.
- [ ] Implement one or more **actually working, testable** adapters/deployers when prerequisites permit; otherwise implement explicit capability/readiness and disabled actions (not pretend functionality).
- [ ] Add supported backend graphics presets only after verifying real supported setting names.
- **Gate:** fixture-backed adapter integration; real runtime/game test only if clean game and OS are available. Do not claim game success otherwise.

## 6. UX, packaging and quality — P0/P1
- [ ] Polish flagship `Clone & Experiment` workflow and mod/snapshot/readiness views.
- [ ] Accessible keyboard/trackpad UX and useful progress/error states.
- [ ] Build release-ish development app, run unit/integration tests and perform a UI smoke test.
- [ ] Document installation, use, missing prerequisites, architecture, safety, and limits in README/DECISIONS.
- [ ] Audit git status/history for secret/game/save files and accidental scope changes.
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
