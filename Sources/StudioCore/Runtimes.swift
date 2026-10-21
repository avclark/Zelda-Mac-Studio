import Foundation

public struct RuntimeReadiness: Equatable {
    public var status: String
    public var reasons: [String]
    public var canLaunch: Bool
}
public protocol RuntimeAdapter {
    var backend: Backend { get }
    var supportedFormats: [String] { get }
    func readiness(osMajor: Int, knownCorruptBase: Bool) -> RuntimeReadiness
    func configure(environment: Adventure) throws
    func launch(environment: Adventure) throws
}
/// Live adapters intentionally fail closed until a particular installed version has a verified isolation contract.
public struct GuardedRuntimeAdapter: RuntimeAdapter {
    public let backend: Backend
    public var supportedFormats: [String] { backend == .ryujinx ? [] : ["romfs"] }
    public init(_ backend: Backend) { self.backend = backend }
    public func readiness(osMajor: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion, knownCorruptBase: Bool = true) -> RuntimeReadiness {
        if backend == .laboratory { return RuntimeReadiness(status: "Implemented + tested with synthetic fixtures", reasons: ["Import, plan, deploy and restore managed overlays locally. This laboratory does not execute games."], canLaunch: false) }
        var reasons: [String] = []
        if knownCorruptBase { reasons.append("The inventoried base NSP failed content integrity checks. Blocked for verified runtime use; obtain a clean, verified personal dump. The manager will not repair it.") }
        if backend == .macNative && osMajor < 26 { reasons.append("Needs macOS 26+ for native gameplay. The manager runs on Sonoma; no OS changes are made.") }
        reasons.append(backend == .macNative ? "Native RomFS manifest workflow researched. Independent save/mod root overrides are not verified against an installed runtime; launch and live deployment are unavailable." : "A compatible emulator, clean game, and verified independent data/save root are required. Existing emulator directories are never adopted or modified.")
        return RuntimeReadiness(status: backend == .macNative && osMajor < 26 ? "Needs OS upgrade · launch blocked" : "Integration unavailable · missing verified game/runtime", reasons: reasons, canLaunch: false)
    }
    public func configure(environment: Adventure) throws { throw StudioError.invalid(readiness().reasons.joined(separator: "\n")) }
    public func launch(environment: Adventure) throws { throw StudioError.invalid(readiness().reasons.joined(separator: "\n")) }
}
/// Tracks only explicitly owned processes. Future adapters can use this without touching unrelated apps.
public final class RuntimeProcessRegistry {
    private var processes: [UUID: Process] = [:]
    private let lock = NSLock()
    public init() {}
    public func track(_ process: Process, for id: UUID) { lock.lock(); defer { lock.unlock() }; processes[id] = process }
    public func isActive(_ id: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; return processes[id]?.isRunning ?? false }
    public func terminate(_ id: UUID) { lock.lock(); defer { lock.unlock() }; if let process = processes[id], process.isRunning { process.terminate() } }
}
public enum Diagnostics {
    /// Allow-list report: user names, file paths, notes, imported file names and raw errors are never included.
    public static func report(_ state: LibraryState) -> String {
        """
        Zelda Mac Studio — sanitized diagnostics
        Schema: \(state.schema)
        Environments: \(state.environments.count)
        Mod packages: \(state.mods.count)
        Snapshots: \(state.snapshots.count)
        OS major: \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        Laboratory import/deploy: implemented; tested with synthetic fixtures
        Resource merging: unavailable
        Native gameplay: blocked; macOS 26+ and clean verified game required
        Emulator gameplay: blocked; isolated adapter not verified
        Gameplay verification: not performed
        Private paths, names, notes, keys, saves and raw logs are excluded from this report.
        """
    }
}
