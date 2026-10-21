# Zelda Mac Studio — Product Requirements Document

**Status:** Implementation-ready v1.0 · **Date:** 2026-10-21 · **Primary target:** 16-inch M1 Max MacBook Pro, 64 GB RAM, 4 TB SSD, macOS 14.6.1 (upgrade to macOS 26 planned). **Secondary target:** Mac Studio, with future sync.  
**First game:** The Legend of Zelda: Tears of the Kingdom (TOTK). Other games, including BOTW, are architectural extensibility goals, not v1 feature commitments.

## 1. Product intent

Build a **native SwiftUI Mac application** that makes exploring TOTK mods easy, understandable, and reversible. The defining interaction is **Clone & Experiment**: preserve a known-good adventure, duplicate its configuration and optionally its save, try a new mod or overhaul in the duplicate, and return to the original with no damage or guesswork.

The manager is **native macOS** even when its underlying game runtime is an emulator. Prefer a native Apple Silicon TOTK runtime when it provides a comparably stable, mod-compatible experience, but **never sacrifice modding reliability just to label gameplay native**. Support multiple backends through adapters; do not build a new emulator or rewrite a graphics translator.

**Order of priorities:** (1) frictionless mod experimentation, (2) environment/save isolation and rollback, (3) honest diagnostics, (4) ambitious content/gameplay mods, (5) stable high visual quality and frame pacing, (6) portable cross-Mac library and eventual sync, (7) other games, (8) controller navigation *within the manager*. Mouse/trackpad/keyboard are the primary manager input; external controller support matters for gameplay.

### 1.1 Non-goals

- Shipping game content, console firmware, keys, proprietary assets, or pirated downloads.
- Guaranteeing all mods work, or claiming successful in-game verification without playing/testing.
- Writing a new Switch emulator, full merge engine, or native rendering engine.
- Automatic cloud sync, full in-app GameBanana marketplace, BOTW implementation, controller-driven manager UI, or universal 4K/60 as hard v1 requirements.
- Repairing or modifying the user's known damaged base NSP.

## 2. Existing user environment and constraints

The user has **already run a read-only Codex inventory on this same MacBook Pro**; do not repeat a full disk search. Findings:

- TOTK **base 1.0.0 NSP**, under `~/Podcast Royale Dropbox/Adam Clark/Games/Ryujinx/Games/`. This file **fails content integrity checks**: 10 failing 16 KiB RomFS blocks, in two clusters. Do not trust for game execution or claim the app is fully tested using it.
- TOTK **update 1.2.1 NSP**, under `~/Podcast Royale Dropbox/Adam Clark/Games/Ryujinx/Updates/`. Primary NCA content hashes passed.
- Existing compatible `prod.keys` in `~/Library/Application Support/Ryujinx/system/`; `title.keys` also exists. Keys are secrets: no logging, publishing, copying into Git, uploading, or displaying contents.
- Existing Ryujinx install, firmware registered-content directory, **TOTK save data**, and shader caches. Preserve and back up originals; do not point experimental runs at original live saves.
- Old Cemu/Wii U BOTW install exists but **not relevant to v1**.
- 64 GB memory and ~1.29 TB available at time of scan; macOS Sonoma 14.6.1. Full Xcode version not yet audited.
- Current upstream MacNativeGames reports **macOS 26+** (Metal 4) for game execution, and accepts base 1.0.0 NSP/XCI, a separate supported update, keys, and—when needed—shared fonts/firmware. **Do not conflate the native manager's Sonoma compatibility with the native game runtime's OS requirement.**

The canonical inventory is *not part of this repository*. Ask for the inventory text only if needed for deeper investigation. Do not embed user-specific absolute paths into source defaults or sample data.

## 3. Core user journeys

### A. First launch/setup
1. Open a real, working `.app` with clear empty state and a Setup/Readiness checklist.
2. Choose an app-managed local workspace and a **portable library folder** through a standard macOS picker. The library may be in Dropbox, iCloud Drive, Synology Drive, or another local filesystem location.
3. Register existing runtime installations and **reference** locally held game inputs/keys without importing secrets into the portable library.
4. See explicit validation statuses: `Not checked`, `Ready`, `Warning`, `Blocked`, with actionable details. A known-corrupt game image is `Blocked for verified runtime use`.
5. Continue using environment/mod/snapshot features with synthetic fixture data if real TOTK build is blocked.

### B. Clone & Experiment — flagship
1. Create a `Main Adventure` environment, based on a template or a *verified* installed game/runtime.
2. Clone it to `Experimental Combat` (copy configuration and optionally independent save state).
3. Import, enable, reorder, or remove mods **in the clone only**.
4. Before deployment, show what will change, whether files conflict, and whether a runtime supports the mod.
5. Launch the clone with the correct backend and isolated save/workspace, or show a truthful blocker.
6. Revert via a snapshot or discard the clone without affecting Main Adventure.
7. Compare two environments or snapshots (mods, versions, runtime, settings, saves metadata).

### C. Try a new mod
1. Drag/drop a downloaded archive or select a local folder/archive. Start with ZIP and directory import; other formats only if supported by a verified library/tool.
2. Show mod identity/source/version and **Detected format**, **Supported by current runtime?**, **Potential conflicts?**, and **Verification status**.
3. Treat unknown or ambiguous metadata as unknown rather than compatible.
4. Do not execute scripts or binaries bundled in mod archives; reject unsafe paths, symlinks escaping staging, malformed archives, oversized expansion, and unexpected formats.
5. Store an immutable original import, hash it, and stage a derived deployment overlay. Preserve provenance and installation logs.
6. A successful file deployment must NOT display “works in game”; allow manual confirmation and environment-specific notes/test instructions.
7. Restore/disable should produce a precisely testable change to overlay/configuration, without touching immutable originals.

### D. Portable library
1. Select any writable local folder; avoid hardcoded Dropbox APIs.
2. Export/publish environment definitions, original mod archives, ordered mod selection, compatibility notes, content-addressed manifests, and **immutable save snapshots**.
3. Import on another Mac using a local workspace, resolving paths via runtime/game registration rather than absolute paths.
4. Avoid syncing active runtime saves, caches, logs, executable builds, keys, firmware, or game images by default.
5. Handle incomplete cloud sync, file-provider placeholders, interrupted writes, and divergent save branches safely. No timestamp-only last-writer-wins.
6. Initial v1: robust manual export/import or `Publish`/`Pull` with conflict detection. Automatic multi-Mac synchronization is a subsequent phase, built upon the same schema.

## 4. Functional requirements and acceptance criteria

### FR-01 Native manager shell (P0)
- SwiftUI app with navigation for **Library / Environments / Mods / Snapshots / Runtimes / Settings & Diagnostics**; accessible from keyboard/trackpad.
- Real app bundle that builds and launches on the primary MBP's supported toolchain; app icon and polished but restrained UI.
- Empty, loading, error, blocked, and success states. No placeholder buttons that falsely appear functional; unsupported operations should be explicitly unavailable with reason.
- Onboarding uses consented folder selection, not unrestricted home directory scanning.

### FR-02 Persistent domain model (P0)
- Stable UUIDs; schema-versioned persistence/migrations; game ID, game version, runtime ID/version, environment, mod package/variant, enabled mod order, deployment generation, save lineage, graphics overrides, snapshots, validation records.
- Separate content identities (hashes) from human-readable names; no dependence on mod title alone.
- Persist through app restarts and recover interrupted operations. Database (e.g., SQLite) vs file-based metadata may be chosen based on trade-offs; portable interop format must be documented.

### FR-03 Environment isolation (P0)
- Create, rename, duplicate, delete, archive and compare environments; deletion requires confirmation and recoverable staging/trash policy.
- Cloning MUST copy mutable state (or use safe copy-on-write semantics), including saves when chosen; mutable paths can never be shared across environments.
- Share immutable base game/content where a backend allows it without changing game data. Keep a consistent mapping from environment to runtime, mod profile, save root and working overlay.
- No profile switch, mod deployment or rollback while the relevant runtime is running; detect active process and refuse/wait safely.
- **Tests:** changing/removing a mod or save in clone leaves origin bit-for-bit unchanged; deleting clone leaves origin accessible.

### FR-04 Snapshots / rollback / saves (P0)
- Snapshot configuration, mod overlay manifest, and save state where available; snapshots immutable and timestamped with UUID and hash manifest.
- Automatic pre-deployment snapshot for real mod changes; manual Create Snapshot and Restore Snapshot with preview and confirmation.
- Restore is transactional: validate, stage, swap atomically where possible, verify, retain previous state for recovery.
- Preserve existing Ryujinx saves before any integration, with user-approved destination; never modify original saves in place.
- Distinguish “save-compatible,” “unverified,” and “not supported.” Do not imply save migration between backends is automatic.

### FR-05 Mod importing and library (P0)
- ZIP/folder imports using sandboxed or careful bounded extraction, path traversal defense, archive quota, symlink checks, hashes, duplicate detection, metadata where found, import origin, and log.
- Recognize candidate `romfs` / `exefs` / cheats / patches / unknown. Version/runtime matrix is explicit. Unknown is not success.
- Enable/disable/reorder independently per environment; generate deterministic deployment plan and diff.
- Detect same-path collisions at minimum; **do not advertise semantic/resource merging as solved** unless integrated and tested.
- Test with synthetic fixtures: benign mod, duplicate, malicious `../`, oversized archive, symlink, overlapping resource and unsupported ExeFS.

### FR-06 Mod merging and deployment (P1)
- Investigate current [TKMM](https://github.com/TKMM-Team/TKMM) licenses, libraries/CLI and official merge behavior; prefer tested reuse over reimplementation. Do not automate a GUI via fragile click coordinates as the primary integration.
- Implement runtime-independent planning and pluggable deployers. Backend adapter declares supported format, version constraints, merge capacity, mod location and integrity checks.
- Native MacNativeGames path: honor official RomFS/manifest workflow **only if current source confirms it**; ExeFS/code modifications explicitly blocked unless a future runtime implements them.
- Emulator path: inspect supported mod directory structure/command-line/config/save overrides before declaring independent environments supported.
- Deploy from staging and verify resulting files/hashes. On conflict without a reliable merger, stop and present choices; never silently overwrite.
- Implement a known-good synthetic deployment end-to-end first; actual in-game verification is a separate gated result.

### FR-07 Runtimes (P1)
- `RuntimeAdapter` protocol for capability discovery, readiness, configure, deploy, launch, monitor, terminate (gracefully), extract errors, locate saves and runtime status.
- Adapters must distinguish `Implemented + tested`, `Implemented + not tested`, `Unsupported`, `Needs OS upgrade`, and `Missing game files`.
- Assess current supported Apple Silicon Switch emulators via official projects; don't assume historical Ryujinx or one contemporary emulator is best.
- Assess MacNativeGames as native runtime candidate; **requires macOS 26+** and valid input. Do not auto-upgrade OS or attempt a native game build on Sonoma.
- Existing corrupt base NSP MUST fail trusted readiness; user may separately opt into diagnostic parse-only investigation, never silently promote it.
- Game installation and keys remain outside Git and portable library; avoid logs containing secret values.
- Graphics profiles implemented only for confirmed backend settings, with per-device overrides and measured performance notes. Do not conflate 4K output/upscaling with 4K internal rendering, or interpolated with simulated/rendered FPS.

### FR-08 Portable library and sync foundation (P1)
- Local Application Support working directory and separately user-selected portable library. Support external file providers through standard filesystem APIs and security-scoped bookmarks when needed.
- Export/import schema-versioned manifests with checksums, stable IDs and relative references; immutable versions, temp-file staging and atomic promotion where supported.
- Detect missing/corrupt files and conflicting histories; keep both save branches. Never overwrite silently; no live active-save sync.
- Handles offline usage and directory temporarily missing. Clear sync/publish status and last verified operation.
- **Tests:** round-trip between independent local test roots; interrupted partial export not accepted; simulated divergent snapshots both retained; no absolute MBP paths or secrets exported.

### FR-09 Diagnostics / transparency (P0)
- User-facing readiness panel, last operation status, package validation, deployment manifest/diff, logs and a “why can't I play this?” explanation.
- Test and present stages distinctly: **Archive imported → Validated → Merged/Deployed → Runtime launched → User-verified in-game**.
- No blanket green success indicator for the entire chain when only early stages passed.
- Any blocked feature has an explicit explanation and actionable next step; allow exporting sanitized diagnostic bundle after preview.

### FR-10 Future-proofing (P2 architecture only)
- Game definition schema separate from runtime and mod format. Future BOTW and other Zelda games plug into a game adapter/descriptor. Do not implement their actual assets/mod adapters for v1.
- Cross-device automatic sync engine, GameBanana in-app discovery/download, controller navigation, and broader archive support are deferred and must not crowd out core reliability.

## 5. UX design requirements

- Native macOS patterns, keyboard/trackpad first; clear sidebar, detail panels, actionable buttons, confirmation dialogs, drag/drop, progress and empty states.
- Primary screen focuses on environments (not emulator internals). Prominent **Create Environment**, **Clone & Experiment**, **Try a Mod**, **Snapshot**, **Revert**, **Play**.
- Preview exact impact before destructive or deploy actions; understandable language (“This mod needs executable patches; native backend only loads asset mods”).
- Use intentional statuses; no fabricated mod ratings, gameplay confirmations or performance numbers.
- Never hide functional errors behind decorative badges.

## 6. Technical guidance

- Prefer **Swift + SwiftUI**, modular layers (`Domain`, `Persistence`, `Filesystem`, `ModImport`, `ModPlan`, `RuntimeAdapters`, `PortableLibrary`, `UI`) and dependency injection for tests.
- Adopt a Sonoma-compatible Xcode/SDK available on the machine; **Xcode 16.2 supports macOS Sonoma 14.5+**. If available toolchain differs, establish compatible fallback. Avoid requiring modern SwiftUI APIs not available at the deployment target.
- Implement filesystem operations using staged directories, hashes, careful path handling, atomic swaps where feasible, file locks/runtime activity tracking and well-defined rollback.
- Keep the original game files, downloaded archives, save source and keys immutable. Don't execute arbitrary downloaded mod code.
- Secure any security-scoped bookmarks and local sensitive paths; do not store key contents. Never silently grant Full Disk Access, weaken Gatekeeper, or disable System Integrity Protection.
- Keep build scripts safe with paths containing spaces. Treat upstream libraries as independently versioned optional integrations; pin tested versions and record licenses.
- Prefer local operation; external discovery/documentation is allowed but never transmit local game files, keys or saves.

## 7. Definition of done for first autonomous implementation

**Must deliver (P0):** compiling/launchable Sonoma SwiftUI `.app`; persistent environments; clone isolation; importing sample ZIP/folder mods; enable/disable and deterministic plan; simple path conflict and unsupported-format handling; snapshot/restore; truthful diagnostics; automated tests for corruption/conflict/isolation/rollback; README and safe install/open instructions; Git commits.

**Strongly desired if verifiable (P1):** functioning real runtime adapter(s), TKMM or other verified merge integration, real mod deployment, configurable graphics controls, portable library round-trip, basic safe publish/pull, robust logs.

**Explicitly acceptable blockers:** damaged base game, current OS before macOS 26, missing runtime APIs, external packages/licensing, absent user's permissions. Affected functionality must remain clearly blocked in the app and named in final report; other work continues.

**Non-acceptance:** UI-only pretend installers or launches; clones sharing mutable saves; backups that cannot restore; deleting or rewriting the original NSP; claiming mod gameplay compatibility without a game test; unsafe archive extraction; cloud auto-sync corrupting divergent saves; checking keys into Git.

## 8. Verification and evaluation

- Unit tests for domain storage/schema migration, clone deep isolation, snapshot hashes, rollback, mod import and validation, archive attacks, file conflicts, deterministic plans, sync manifest integrity and conflict branches.
- Integration tests with **synthetic fixture games/mods/saves** to prove deploy/disable/revert without proprietary assets.
- Build signed locally if supported, otherwise development-signed and launchable through standard local development; no ad hoc Gatekeeper bypass instructions.
- Measure tests run/passed, actual build command/result, UI smoke launch and known untested parts; distinguish automated fixture validation from game tested on Mac.
- Later **real game acceptance test**: with a clean verified dump and compatible OS, launch TOTK, install a visible known-compatible mod in a clone, confirm in-game effect, disable/revert and verify original unaffected. Only then declare end-to-end modding verified.

## 9. Source references for engineering verification

- Native runtime: https://github.com/ly05010419/MacNativeGames
- Mod manager: https://github.com/TKMM-Team/TKMM
- TOTK mods/catalog: https://gamebanana.com/games/7617
- Apple toolchain support: https://developer.apple.com/xcode/system-requirements

Source behavior changes rapidly. Check actual upstream repos and licenses before integration; do not elevate prior conversation claims to verified facts.
