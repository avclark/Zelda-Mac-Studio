import Foundation
import CryptoKit
import Darwin

public enum SafeFiles {
    public static let fm = FileManager.default
    public static func directory(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
    public static func encode<T: Encodable>(_ object: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(object)
    }
    public static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    public static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func hashFile(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var sha = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { sha.update(data: data) }
        return sha.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public static func safePath(_ path: String) throws {
        guard !path.isEmpty, path.utf8.count <= 1024, !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"),
              !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
              path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw StudioError.invalid("Unsafe or ambiguous file path rejected.")
        }
    }
    public static func rejectPrivateInput(_ path: String) throws {
        let lower = path.lowercased(), ext = (path as NSString).pathExtension.lowercased()
        guard !["nsp", "xci", "nsz", "nca", "keys", "pem", "key"].contains(ext),
              !lower.split(separator: "/").contains(where: { ["firmware", "system", "saves"].contains(String($0)) }) else {
            throw StudioError.invalid("Game images, keys, firmware and save directories cannot be imported as mods.")
        }
    }
    public static func regularFiles(_ root: URL, maxBytes: Int = 1_073_741_824, maxFiles: Int = 20_000) throws -> [String: String] {
        let rv = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard rv.isDirectory == true, rv.isSymbolicLink != true else { throw StudioError.invalid("Expected a real directory; symbolic links are not allowed.") }
        var result: [String: String] = [:], seen = Set<String>(), total = 0, count = 0
        var traversalError: Error?
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey], options: [], errorHandler: { _, error in traversalError = error; return false }) else { throw StudioError.invalid("Cannot read directory.") }
        for case let url as URL in enumerator {
            let path = String(url.path.dropFirst(root.path.count + 1)); try safePath(path)
            count += 1; guard count <= maxFiles else { throw StudioError.invalid("File count limit exceeded.") }
            let normalized = path.precomposedStringWithCanonicalMapping.lowercased()
            guard seen.insert(normalized).inserted else { throw StudioError.invalid("Case or Unicode path collision.") }
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            guard values.isSymbolicLink != true else { throw StudioError.invalid("Symbolic links are not allowed.") }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw StudioError.invalid("Special files are not allowed.") }
            let attrs = try fm.attributesOfItem(atPath: url.path)
            guard (attrs[.referenceCount] as? NSNumber)?.intValue ?? 1 == 1 else { throw StudioError.invalid("Hard links are not allowed.") }
            total += values.fileSize ?? maxBytes + 1
            guard total <= maxBytes else { throw StudioError.invalid("Expanded size limit exceeded.") }
            result[path] = try hashFile(url)
        }
        if traversalError != nil { throw StudioError.invalid("Directory is incomplete or unreadable. Wait for local download.") }
        return result
    }
    public static func copyTree(_ source: URL, _ destination: URL) throws {
        let manifest = try regularFiles(source)
        try directory(destination)
        for path in manifest.keys.sorted() {
            let target = destination.appendingPathComponent(path); try directory(target.deletingLastPathComponent())
            try fm.copyItem(at: source.appendingPathComponent(path), to: target)
        }
        guard try regularFiles(destination) == manifest else { throw StudioError.invalid("Copy verification failed; source may have changed.") }
    }
    public static func verify(_ root: URL, _ manifest: [String: String]) throws {
        guard try regularFiles(root) == manifest else { throw StudioError.invalid("Checksum mismatch or incomplete data; operation stopped.") }
    }
    public static func atomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
    public static func cleanName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120, !trimmed.contains("/"), !trimmed.contains("\\"), !trimmed.unicodeScalars.contains(where: { $0.value < 32 }) else { throw StudioError.invalid("Use a name of 1–120 characters without slashes or control characters.") }
        return trimmed
    }
}
