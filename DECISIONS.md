# Engineering decisions

- Sonoma 14 deployment target; Xcode 16.2 / Swift 6.0.3 in Swift 5 language mode. Native SwiftUI UI and Foundation/CryptoKit core. No downloaded dependencies.
- Local schema-versioned JSON catalog references immutable environment revisions. Each change stages a new revision; a single atomic catalog replacement commits it. Snapshots retain old revisions. A failed commit leaves the prior catalog valid and staged data unreferenced. No destructive garbage collection in v1.
- Every clone has copied save and overlay files under a new environment UUID. No shared mutable runtime directories. No direct access to existing emulator state.
- ZIP support uses a strict parser plus the macOS system zlib for bounded decompression and CRC verification. Unsupported ZIP features fail closed. Folder imports reject links and special files.
- A local laboratory deployer is useful for verifiable overlay workflows. It does not pretend to launch a game. Runtime adapters must remain unavailable until their isolation and real prerequisites are verified.
