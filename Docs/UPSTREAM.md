# Runtime and merge research — 2026-10-21

No upstream code or binaries were downloaded, executed, incorporated or installed. These moving upstream branches are research references, not pinned dependencies. All shipped code is local and uses Apple frameworks/system zlib.

## MacNativeGames

[Repository](https://github.com/ly05010419/MacNativeGames), [mod documentation](https://github.com/ly05010419/MacNativeGames/blob/main/docs/mods.md), [license](https://github.com/ly05010419/MacNativeGames/blob/main/LICENSE).

MIT project with separate third-party notices. Native gameplay requires macOS 26+; manager compilation does not. The documented loader consumes RomFS asset paths through a TSV manifest containing size, modified SHA-256 and original SHA-256. General ExeFS/IPS integration is unsupported. A generated manifest needs the clean game's original resources. Default mods and saves use global per-game paths; this app must not use them without verified environment overrides. No build or launch attempted on Sonoma, no private inputs accessed.

## TKMM / TkSharp

[TKMM](https://github.com/TKMM-Team/Tkmm), [TkSharp](https://github.com/TKMM-Team/TkSharp), [merge project](https://github.com/TKMM-Team/TkSharp/blob/master/TkSharp.Merging/TkSharp.Merging.csproj), [app project](https://github.com/TKMM-Team/Tkmm/blob/master/src/Tkmm/Tkmm.csproj).

Both repositories identify MIT licenses. TkSharp separates core, packaging and resource merging. The reviewed merging project targets .NET 10 and references BsDiff, Revrs, RstbLibrary and other packages. TKMM references a Tkmm.CLI project, so a CLI exists; command contract, game-resource prerequisites, complete dependency-license review, pinned build and fixture integration remain unverified. No claim that the merge engine is absent or impossible. No GUI automation attempted. Current planner blocks same-path collisions rather than silently resolving them by load order.

## Emulator candidates

- [Ryubing documentation](https://docs.ryujinx.app/guides/setup-guide/) describes macOS support and user-supplied keys/firmware. Its canonical [source host](https://git.ryujinx.app/ryubing/ryujinx) timed out during this audit. Historical Ryujinx data-directory behavior is insufficient evidence for a current isolated launcher. Existing install was observed by app name only; no emulator files, saves or secrets inspected.
- [Astris distribution](https://github.com/V380-Ori/Astris.Binaries) identifies Apple Silicon and macOS 15+, above this machine's OS. Distribution listing alone does not verify a source/API isolation contract.
- [Sol](https://github.com/Zinedinarnaut/Sol) is an Apple Silicon SwiftUI/AppKit frontend with a Ryubing-derived backend and MIT repository license. Not installed or fixture-integrated; no stability or compatibility claim.

## Result

The working deployer targets a manager-owned laboratory overlay. Native/emulator adapters expose truthful readiness and reject launch/configuration. The process registry is tested with an owned system sleep process; this is process-lifecycle verification, not game-runtime verification. Graphics controls, live deployment, game launch, backend save migration and resource merging remain explicitly unavailable until a clean dump and version-specific isolation contract can be tested.
