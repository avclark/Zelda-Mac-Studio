import Foundation

public enum StudioError: Error, LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public enum Backend: String, Codable, CaseIterable, Identifiable {
    case laboratory, macNative, ryujinx
    public var id: String { rawValue }
    public var title: String { switch self { case .laboratory: return "Local mod laboratory"; case .macNative: return "MacNativeGames"; case .ryujinx: return "Ryujinx / Ryubing" } }
}
public struct Adventure: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var gameID = "0100F2C0115B6000"
    public var gameVersion = "Unknown"
    public var backend: Backend = .laboratory
    public var revision = UUID()
    public var parentID: UUID?
    public var enabledMods: [String] = []
    public var archived = false
    public var trashed = false
    public var generation = 0
    public var notes = ""
    public var gameplayVerified = false
    public var created = Date()
    public init(name: String) { self.name = name }
}
public struct ModPackage: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var files: [String: String]
    public var formats: [String]
    public var imported: Date
    public var origin: String // Folder or ZIP; never a private absolute path.
    public var originalArchiveHash: String?
    public var version = "Unknown"
    public var compatibility = "Not checked; gameplay unverified"
}
public struct Snapshot: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var environment: Adventure
    public var label: String
    public var created = Date()
    public var manifest: [String: String]
}
public struct LibraryState: Codable {
    public var schema = 1
    public var environments: [Adventure] = []
    public var mods: [ModPackage] = []
    public var snapshots: [Snapshot] = []
    public var events: [String] = []
    public init() {}
}
public struct DeploymentPlan {
    public var files: [String: String] = [:] // destination -> package ID
    public var hashes: [String: String] = [:]
    public var blockers: [String] = []
    public var added: [String] = []
    public var changed: [String] = []
    public var removed: [String] = []
    public var canDeploy: Bool { blockers.isEmpty }
}
public struct PortableManifest: Codable {
    public var schema = 1
    public var publication = UUID()
    public var environment: Adventure
    public var mods: [ModPackage]
    public var snapshots: [Snapshot]
    public var files: [String: String]
}
