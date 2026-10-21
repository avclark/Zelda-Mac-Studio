import XCTest
import CZip
@testable import StudioCore

final class ModTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try SafeFiles.directory(root) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func folder(_ name: String, _ path: String = "romfs/Actor/test.bin", _ value: String = "synthetic") throws -> URL {
        let url = root.appendingPathComponent(name), file = url.appendingPathComponent(path)
        try SafeFiles.directory(file.deletingLastPathComponent()); try Data(value.utf8).write(to: file); return url
    }
    func testImportDedupDeployDisableRestoreAndCloneIsolation() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), a = try store.create(name: "Main")
        let source = try folder("Mod"), mod = try store.importMod(source)
        XCTAssertEqual(mod.id, try store.importMod(source).id); XCTAssertEqual(store.state.mods.count, 1)
        let b = try store.clone(a.id, name: "Clone", includeSaves: true)
        try store.setMods(b.id, orderedIDs: [mod.id])
        let plan = try store.plan(store.state.environments[1]); XCTAssertTrue(plan.canDeploy); XCTAssertEqual(plan.added, ["romfs/Actor/test.bin"])
        try store.deploy(b.id)
        let deployed = store.state.environments[1]
        XCTAssertEqual(try SafeFiles.regularFiles(store.overlayURL(deployed)), plan.hashes)
        XCTAssertTrue(try SafeFiles.regularFiles(store.overlayURL(a)).isEmpty)
        XCTAssertTrue(store.state.environments[0].enabledMods.isEmpty)
        let snap = try store.snapshot(b.id, label: "Mod enabled")
        try store.setMods(b.id, orderedIDs: [])
        XCTAssertEqual(try store.plan(store.state.environments[1]).removed.count, 1)
        try store.deploy(b.id)
        XCTAssertTrue(try SafeFiles.regularFiles(store.overlayURL(store.state.environments[1])).isEmpty)
        try store.restore(snap.id)
        XCTAssertEqual(try SafeFiles.regularFiles(store.overlayURL(store.state.environments[1])), plan.hashes)
        XCTAssertFalse(store.state.environments[1].gameplayVerified)
    }
    func testConflictsUnsupportedFormatsAndRollback() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), env = try store.create(name: "Test")
        let a = try store.importMod(folder("One", "romfs/test", "one")), b = try store.importMod(folder("Two", "romfs/test", "two"))
        try store.setMods(env.id, orderedIDs: [a.id,b.id]); XCTAssertFalse(try store.plan(store.state.environments[0]).canDeploy)
        XCTAssertThrowsError(try store.deploy(env.id))
        let patch = try store.importMod(folder("Patch", "exefs/test.ips"))
        try store.setMods(env.id, orderedIDs: [patch.id]); XCTAssertThrowsError(try store.deploy(env.id))
        let unknown = try store.importMod(folder("Unknown", "readme.txt"))
        try store.setMods(env.id, orderedIDs: [unknown.id]); XCTAssertThrowsError(try store.deploy(env.id))
        try store.setMods(env.id, orderedIDs: [a.id]); let before = store.state.environments[0]
        store.beforeCommit = { throw StudioError.invalid("Injected failure") }
        XCTAssertThrowsError(try store.deploy(env.id)); XCTAssertEqual(try LibraryStore(root: store.root).state.environments[0], before)
    }
    func testFolderSymlinkPrivateInputAndCorruptPackageRejected() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace"))
        let bad = try folder("Bad"); try FileManager.default.createSymbolicLink(at: bad.appendingPathComponent("link"), withDestinationURL: root)
        XCTAssertThrowsError(try store.importMod(bad))
        XCTAssertThrowsError(try store.importMod(folder("Private", "prod.keys")))
        let mod = try store.importMod(folder("Good")), env = try store.create(name: "Main")
        try store.setMods(env.id, orderedIDs: [mod.id])
        try Data("tampered".utf8).write(to: store.packageURL(mod.id).appendingPathComponent("romfs/Actor/test.bin"))
        XCTAssertThrowsError(try store.deploy(env.id))
    }
    func testZIPRoundTripAndMaliciousPaths() throws {
        let good = try zip("good", entries: [("romfs/test", "test", 0)])
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), mod = try store.importMod(good)
        XCTAssertEqual(mod.formats, ["romfs"]); XCTAssertNotNil(mod.originalArchiveHash)
        for (index, path) in ["../outside", "/absolute", "romfs/../../outside", "a\\b", "a//b"].enumerated() {
            XCTAssertThrowsError(try store.importMod(zip("bad\(index)", entries: [(path,"bad",0)])))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("outside").path))
        XCTAssertThrowsError(try store.importMod(zip("link", entries: [("romfs/link", "target", 0xa000)])))
        XCTAssertThrowsError(try store.importMod(zip("collision", entries: [("romfs/A", "1", 0),("romfs/a", "2", 0)])))
    }
    func testZIPQuotaTruncationCRCAndDeflate() throws {
        let good = try zip("good", entries: [("romfs/test", "0123456789", 0)])
        var importer = ZIPImporter(); importer.maxExpanded = 5
        XCTAssertThrowsError(try importer.extract(good, to: root.appendingPathComponent("too-large")))
        let bad = root.appendingPathComponent("crc.zip"); var data = try Data(contentsOf: good); data[30 + "romfs/test".count] ^= 1; try data.write(to: bad)
        XCTAssertThrowsError(try ZIPImporter().extract(bad, to: root.appendingPathComponent("crc-out")))
        try data.dropLast(10).write(to: bad)
        XCTAssertThrowsError(try ZIPImporter().extract(bad, to: root.appendingPathComponent("truncated")))
        let source = try folder("Deflated", "romfs/test", String(repeating: "synthetic ", count: 500))
        let archive = root.appendingPathComponent("deflated.zip"), process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); process.currentDirectoryURL = source
        process.arguments = ["-q", "-r", archive.path, "romfs"]; try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        let destination = root.appendingPathComponent("deflated-out"); try ZIPImporter().extract(archive, to: destination)
        XCTAssertEqual(try SafeFiles.regularFiles(source), try SafeFiles.regularFiles(destination))
    }
    func zip(_ name: String, entries: [(String,String,Int)]) throws -> URL {
        var local = Data(), central = Data()
        func u16(_ n: Int) -> Data { Data([UInt8(n & 255),UInt8((n >> 8) & 255)]) }
        func u32(_ n: Int) -> Data { u16(n) + u16(n >> 16) }
        for (path, value, mode) in entries {
            let bytes = Data(value.utf8), name = Data(path.utf8), offset = local.count
            let crc = bytes.withUnsafeBytes { Int(zms_crc($0.bindMemory(to: UInt8.self).baseAddress, bytes.count)) }
            local += u32(0x04034b50) + u16(20) + u16(0) + u16(0) + u32(0)
            local += u32(crc) + u32(bytes.count) + u32(bytes.count)
            local += u16(name.count) + u16(0) + name + bytes
            central += u32(0x02014b50) + u16(0x0314) + u16(20) + u16(0) + u16(0) + u32(0)
            central += u32(crc) + u32(bytes.count) + u32(bytes.count)
            central += u16(name.count) + u16(0) + u16(0) + u16(0) + u16(0)
            central += u32(mode << 16) + u32(offset) + name
        }
        var end = u32(0x06054b50) + u16(0) + u16(0)
        end += u16(entries.count) + u16(entries.count)
        end += u32(central.count) + u32(local.count) + u16(0)
        let url = root.appendingPathComponent(name + ".zip"); try (local + central + end).write(to: url); return url
    }
}
