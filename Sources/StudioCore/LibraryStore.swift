import Foundation
import Darwin

/// Serialized catalog commits point at immutable, independently copied revisions.
/// An interrupted stage is never visible through the catalog and is retained for recovery.
public final class LibraryStore {
    public let root: URL
    public private(set) var state = LibraryState()
    private let mutex = NSRecursiveLock()
    private let lockFD: Int32
    public var isRuntimeActive: (UUID) -> Bool
    internal var beforeCommit: (() throws -> Void)? // deterministic fault injection in tests
    private var catalog: URL { root.appendingPathComponent("catalog.json") }

    public init(root: URL, isRuntimeActive: @escaping (UUID) -> Bool = { _ in false }) throws {
        self.root = root.standardizedFileURL
        self.isRuntimeActive = isRuntimeActive
        if SafeFiles.fm.fileExists(atPath: root.path) {
            let values = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw StudioError.invalid("Workspace must be a local directory without symbolic links.") }
            let items = try SafeFiles.fm.contentsOfDirectory(atPath: root.path)
            guard items.isEmpty || items.contains(".zelda-studio") else { throw StudioError.invalid("Choose an empty workspace folder. Existing unrelated data will not be adopted.") }
        }
        try SafeFiles.directory(root)
        lockFD = open(root.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFD >= 0 else { throw StudioError.invalid("Cannot lock workspace.") }
        try locked {
            try Data("Zelda Mac Studio workspace v1".utf8).write(to: root.appendingPathComponent(".zelda-studio"), options: .atomic)
            for folder in ["revisions", "packages", "staging"] { try SafeFiles.directory(root.appendingPathComponent(folder)) }
            if SafeFiles.fm.fileExists(atPath: catalog.path) { try reload() }
            else { try SafeFiles.atomicWrite(SafeFiles.encode(state), to: catalog) }
        }
    }
    deinit { close(lockFD) }
    internal func locked<T>(_ body: () throws -> T) throws -> T {
        mutex.lock(); defer { mutex.unlock() }
        guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw StudioError.invalid("Workspace is busy in another app. Try again after its operation finishes.") }
        defer { flock(lockFD, LOCK_UN) }
        return try body()
    }
    public func refresh() throws { try locked { try reload() } }
    internal func reload() throws {
        let loaded = try SafeFiles.decode(LibraryState.self, Data(contentsOf: catalog))
        guard loaded.schema == 1 else { throw StudioError.invalid("Unsupported workspace schema. Open it with the version that created it.") }
        try Self.validate(loaded)
        state = loaded
    }
    internal static func validate(_ state: LibraryState) throws {
        guard Set(state.environments.map(\.id)).count == state.environments.count,
              Set(state.mods.map(\.id)).count == state.mods.count,
              Set(state.snapshots.map(\.id)).count == state.snapshots.count else { throw StudioError.invalid("Duplicate catalog identities.") }
        for mod in state.mods { try validatePackage(mod) }
        for env in state.environments + state.snapshots.map(\.environment) {
            _ = try SafeFiles.cleanName(env.name)
            guard Set(env.enabledMods).count == env.enabledMods.count,
                  env.enabledMods.allSatisfy({ id in state.mods.contains(where: { $0.id == id }) }) else { throw StudioError.invalid("An environment references missing or duplicate mods.") }
        }
        for snap in state.snapshots { for path in snap.manifest.keys { try SafeFiles.safePath(path) } }
    }
    internal static func validatePackage(_ mod: ModPackage) throws {
        guard mod.id.count == 64, mod.id.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
              mod.id == (try SafeFiles.hash(SafeFiles.encode(mod.files))) else { throw StudioError.invalid("Invalid package identity.") }
        for path in mod.files.keys { try SafeFiles.safePath(path); try SafeFiles.rejectPrivateInput(path) }
    }
    internal func commit(_ next: LibraryState, event: String) throws {
        try Self.validate(next)
        var logged = next; logged.events = Array((logged.events + ["\(ISO8601DateFormatter().string(from: Date())) — \(event)"]).suffix(100))
        try beforeCommit?()
        try SafeFiles.atomicWrite(SafeFiles.encode(logged), to: catalog)
        state = logged
    }
    public func revisionURL(_ env: Adventure) -> URL { root.appendingPathComponent("revisions/\(env.id.uuidString)/\(env.revision.uuidString)") }
    public func savesURL(_ env: Adventure) -> URL { revisionURL(env).appendingPathComponent("saves") }
    public func overlayURL(_ env: Adventure) -> URL { revisionURL(env).appendingPathComponent("overlay") }
    public func packageURL(_ id: String) throws -> URL {
        guard id.count == 64, id.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { throw StudioError.invalid("Invalid package ID.") }
        return root.appendingPathComponent("packages/\(id)/content")
    }
    internal func environment(_ id: UUID) throws -> Adventure {
        guard let env = state.environments.first(where: { $0.id == id }) else { throw StudioError.invalid("Environment no longer exists.") }; return env
    }
    internal func writable(_ id: UUID) throws -> Adventure {
        let env = try environment(id)
        guard !isRuntimeActive(id) else { throw StudioError.invalid("Quit the runtime before changing this environment.") }
        guard !env.trashed else { throw StudioError.invalid("Recover this environment from Trash first.") }
        return env
    }
    internal func stageRevision(from old: Adventure?, to env: Adventure) throws {
        let dest = revisionURL(env)
        guard !SafeFiles.fm.fileExists(atPath: dest.path) else { throw StudioError.invalid("Revision already exists.") }
        if let old { try SafeFiles.copyTree(revisionURL(old), dest) }
        else { try SafeFiles.directory(dest) }
        try SafeFiles.directory(dest.appendingPathComponent("saves")); try SafeFiles.directory(dest.appendingPathComponent("overlay"))
    }
    internal func replace(_ env: Adventure, in state: inout LibraryState) {
        if let index = state.environments.firstIndex(where: { $0.id == env.id }) { state.environments[index] = env }
        else { state.environments.append(env) }
    }
    @discardableResult public func create(name: String) throws -> Adventure {
        try locked {
            try reload(); let env = Adventure(name: try SafeFiles.cleanName(name))
            try stageRevision(from: nil, to: env)
            var next = state; next.environments.append(env); try commit(next, event: "Environment created."); return env
        }
    }
    @discardableResult public func clone(_ id: UUID, name: String, includeSaves: Bool) throws -> Adventure {
        try locked {
            try reload(); let old = try writable(id)
            var env = old; env.id = UUID(); env.revision = UUID(); env.parentID = old.id; env.name = try SafeFiles.cleanName(name)
            env.archived = false; env.created = Date(); env.gameplayVerified = false
            try stageRevision(from: old, to: env)
            if !includeSaves { try SafeFiles.fm.removeItem(at: savesURL(env)); try SafeFiles.directory(savesURL(env)) }
            var next = state; next.environments.append(env); try commit(next, event: "Independent clone created."); return env
        }
    }
    public func update(_ id: UUID, name: String? = nil, backend: Backend? = nil, notes: String? = nil, archived: Bool? = nil, gameVersion: String? = nil) throws {
        try locked {
            try reload(); var env = try writable(id)
            if let name { env.name = try SafeFiles.cleanName(name) }
            if let backend { env.backend = backend; env.gameplayVerified = false }
            if let notes { guard notes.count <= 10_000 else { throw StudioError.invalid("Notes are too long.") }; env.notes = notes }
            if let archived { env.archived = archived }
            if let gameVersion { env.gameVersion = try SafeFiles.cleanName(gameVersion) }
            var next = state; replace(env, in: &next); try commit(next, event: "Environment configuration updated.")
        }
    }
    public func setTrashed(_ id: UUID, _ trashed: Bool) throws {
        try locked {
            try reload(); var env = try environment(id)
            guard !isRuntimeActive(id) else { throw StudioError.invalid("Quit the runtime before moving this environment.") }
            env.trashed = trashed
            var next = state; replace(env, in: &next); try commit(next, event: trashed ? "Environment moved to recoverable Trash." : "Environment recovered from Trash.")
        }
    }
    internal func snapshotRecord(_ env: Adventure, label: String) throws -> Snapshot {
        Snapshot(environment: env, label: try SafeFiles.cleanName(label), manifest: try SafeFiles.regularFiles(revisionURL(env)))
    }
    @discardableResult public func snapshot(_ id: UUID, label: String) throws -> Snapshot {
        try locked {
            try reload(); let env = try writable(id), snap = try snapshotRecord(env, label: label)
            var next = state; next.snapshots.append(snap); try commit(next, event: "Immutable snapshot recorded and checksummed."); return snap
        }
    }
    public func restore(_ snapshotID: UUID) throws {
        try locked {
            try reload()
            guard let snap = state.snapshots.first(where: { $0.id == snapshotID }) else { throw StudioError.invalid("Snapshot missing.") }
            let old = try writable(snap.environment.id)
            try SafeFiles.verify(revisionURL(snap.environment), snap.manifest)
            var env = snap.environment; env.revision = UUID(); env.name = old.name; env.trashed = false; env.gameplayVerified = false
            try stageRevision(from: snap.environment, to: env)
            try SafeFiles.verify(revisionURL(env), snap.manifest)
            var next = state; next.snapshots.append(try snapshotRecord(old, label: "Before restore")); replace(env, in: &next)
            try commit(next, event: "Snapshot restored; previous revision retained.")
        }
    }
    /// Only used for a generated demo or explicit managed-save updates, never original emulator saves.
    public func writeManagedSave(_ id: UUID, path: String, data: Data) throws {
        try locked {
            try reload(); let old = try writable(id); try SafeFiles.safePath(path)
            var env = old; env.revision = UUID(); env.gameplayVerified = false
            try stageRevision(from: old, to: env)
            let target = savesURL(env).appendingPathComponent(path); try SafeFiles.directory(target.deletingLastPathComponent())
            try SafeFiles.atomicWrite(data, to: target)
            var next = state; replace(env, in: &next); try commit(next, event: "Managed save revision recorded.")
        }
    }
    public func compare(_ a: Adventure, _ b: Adventure) throws -> String {
        let lhs = try SafeFiles.regularFiles(revisionURL(a)), rhs = try SafeFiles.regularFiles(revisionURL(b))
        let changes = Set(lhs.keys).union(rhs.keys).filter { lhs[$0] != rhs[$0] }.sorted()
        return "Runtime: \(a.backend.title) → \(b.backend.title)\nGame version: \(a.gameVersion) → \(b.gameVersion)\nEnabled mods: \(a.enabledMods.count) → \(b.enabledMods.count)\nMod selection/order changed: \(a.enabledMods != b.enabledMods ? "Yes" : "No")\nChanged save/overlay files: \(changes.count)\n" + changes.joined(separator: "\n")
    }
}
