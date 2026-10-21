# Verification report — 2026-10-21

## Environment

Read-only audit: macOS 14.6.1 (23G93), Apple Silicon, Xcode 16.2 (16C5032a), Swift 6.0.3, macOS SDK 15.2, Git 2.39.5, Homebrew 6.0.18. No system tools installed, settings changed, permissions granted or OS upgraded. .NET was not found on PATH.

## Automated behavior

Command: `swift test --scratch-path .build --cache-path .build/cache`.

**24 XCTest cases passed, zero failures.** The trailing Swift Testing runner reports zero tests because this project uses XCTest; it is not the suite result.

| Suite | Cases | Behaviors covered |
|---|---:|---|
| FoundationTests | 2 | Schema round-trip, unsafe relative paths |
| EnvironmentTests | 5 | Create/reopen, clone/save isolation, no-save clone, recoverable Trash, corrupt snapshot rejection, restore hashes, injected commit failure, running guard, future schema/unrelated folder rejection |
| ModTests | 5 | Folder/ZIP dedup, immutable archive hash, deterministic overlay, independent clone mods, disable/revert, conflicts, ExeFS/unknown blocking, rollback, symlinks/private extensions, tampering, traversal/absolute/backslash paths, case collisions, quotas, CRC, truncation, real system-generated deflate ZIP |
| PortableTests | 3 | Independent-root round-trip, save branch preservation, missing marker, corrupt payload, conflicted sync metadata, failed import commit, default save exclusion and directory-overlap rejection |
| RuntimeTests | 3 | No corrupt/missing-game promotion, no pretend launch, owned system sleep process monitor/terminate, diagnostic allow-list |
| HardeningTests | 6 | Multi-instance reload, no symlink-redirection writes, stale preview rejection, reordering determinism, mod publication round-trip, unexpected export file rejection, hard links/case conflicts, read-only source save copy and restore |

All test inputs are generated synthetic data. Neither TOTK content nor real saves/keys were read or used. Failure injection occurs before catalog commit; this is not a destructive power-loss or disk-full test.

## Native build and launch

Command: `xcodebuild -project ZeldaMacStudio.xcodeproj -scheme ZeldaMacStudio -configuration Release -derivedDataPath build/DerivedData build`.

Result: **BUILD SUCCEEDED**. Bundle: `build/DerivedData/Build/Products/Release/ZeldaMacStudio.app`. Ad-hoc local signature verified using `codesign --verify --deep --strict`. Project and Info.plist passed `plutil -lint`.

Actual app launch used a disposable `build/SmokeWorkspace`. Native accessibility inspection showed a titled Zelda Mac Studio window, six navigation destinations, the empty environment list, Create Environment button and ready-workspace message. This proves the app launched and constructed its initial native interface.

The UI automation transport then failed with `Sky Computer Use native pipe closed before response`; another observation and a reconnect/reset also failed. Full button-by-button workflow, screenshots, visual polish, pickers, drag/drop, bookmark behavior across reboot, keyboard/VoiceOver acceptance and cross-Mac UI acceptance are **not verified**. Core automated tests cover the underlying operations but do not replace those checks.

## Restrictions / external blockers

- Known base game fails integrity per the supplied inventory. It remains blocked; no repair or diagnostic parse was attempted.
- Native game execution requires macOS 26+ upstream. Sonoma is supported by this manager. No upgrade was attempted.
- No pinned runtime with verified independent save/config/mod paths is integrated. Runtime app references are bookmarks only. Game Play, live deployment, graphics controls and backend save migration are unavailable.
- TKMM/TkSharp research found a CLI project and .NET 10 merge code. Command contract, dependency licensing/build, original-game-resource requirements and real merge behavior are not integration-tested. Same-path collision resolution remains manual via disabling a mod.
- File-provider states are simulated on local directories. Actual provider offline/placeholder/conflict behavior and cross-Mac transfer remain untested. Automatic sync is deferred.
- Workspaces retain history and failed-operation remnants. No automatic cleanup exists. Content is immutable through service APIs, not protected against arbitrary same-user tampering. No hard power-failure durability guarantee.

## Delivery safeguards

`.gitignore` excludes game containers, keys, firmware, real save extensions, app/build output, workspace internals, portable publications and logs. `Scripts/audit_tracked.py` checks tracked paths/private-key blocks without printing contents. No Git push was performed. Original PRD/AGENTS documents are retained; PLAN was updated as authorized.

Milestone history begins with foundation `b0e4aeb`, environment/snapshot isolation `798fa24`, mod workflow `35c6092`, and portable/runtime boundaries `329706b`. Later UI/hardening and documentation commits complete this delivery; see `git log --oneline`.
