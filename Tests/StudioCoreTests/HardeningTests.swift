import XCTest
@testable import StudioCore
final class HardeningTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try SafeFiles.directory(root) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testSaveFolderCopyPreservesSourceAndRestoresManagedState() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), env = try store.create(name: "Test")
        try store.writeManagedSave(env.id, path: "slot", data: Data("old-managed".utf8))
        let source = root.appendingPathComponent("selected-save"); try SafeFiles.directory(source)
        try Data("read-only-source".utf8).write(to: source.appendingPathComponent("slot"))
        let before = try SafeFiles.regularFiles(source)
        try store.importManagedSaves(env.id, from: source)
        XCTAssertEqual(try SafeFiles.regularFiles(source), before)
        XCTAssertEqual(try SafeFiles.regularFiles(store.savesURL(store.state.environments[0])), before)
        try store.writeManagedSave(env.id, path: "slot", data: Data("experiment".utf8))
        XCTAssertEqual(try SafeFiles.regularFiles(source), before)
        try store.restore(store.state.snapshots[0].id)
        XCTAssertEqual(try String(contentsOf: store.savesURL(store.state.environments[0]).appendingPathComponent("slot")), "old-managed")
    }
    func testConcurrentStoresReloadBeforeCommit() throws {
        let path = root.appendingPathComponent("workspace"), a = try LibraryStore(root: path), b = try LibraryStore(root: path)
        let one = try a.create(name: "One"), two = try b.create(name: "Two")
        try a.refresh(); XCTAssertEqual(a.state.environments.map(\.id), [one.id, two.id])
        try a.update(one.id, name: "Renamed", archived: true)
        try b.refresh(); XCTAssertEqual(b.state.environments[0].name, "Renamed"); XCTAssertTrue(b.state.environments[0].archived)
    }
    func testWorkspaceSymlinkCannotRedirectWrites() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), env = try store.create(name: "Test")
        let outside = root.appendingPathComponent("outside"); try SafeFiles.directory(outside)
        let saves = store.savesURL(env); try FileManager.default.removeItem(at: saves)
        try FileManager.default.createSymbolicLink(at: saves, withDestinationURL: outside)
        XCTAssertThrowsError(try store.writeManagedSave(env.id, path: "private", data: Data("bad".utf8)))
        XCTAssertTrue(try SafeFiles.regularFiles(outside).isEmpty)
    }
    func testStalePreviewCannotDeploy() throws {
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), env = try store.create(name: "Test")
        try store.writeManagedSave(env.id, path: "changed", data: Data("new state".utf8))
        XCTAssertThrowsError(try store.deploy(env.id, expected: env))
    }
    func testReorderDeterministicAndPortableModsRoundTrip() throws {
        let a = try LibraryStore(root: root.appendingPathComponent("a")), b = try LibraryStore(root: root.appendingPathComponent("b")), env = try a.create(name: "Test")
        var ids: [String] = []
        for name in ["One", "Two"] {
            let source = root.appendingPathComponent(name); try SafeFiles.directory(source.appendingPathComponent("romfs"))
            try Data(name.utf8).write(to: source.appendingPathComponent("romfs/" + name))
            ids.append(try a.importMod(source).id)
        }
        try a.setMods(env.id, orderedIDs: ids); let first = try a.plan(a.state.environments[0])
        try a.setMods(env.id, orderedIDs: ids.reversed()); let second = try a.plan(a.state.environments[0])
        XCTAssertEqual(first.hashes, second.hashes); XCTAssertEqual(first.added, second.added)
        try a.deploy(env.id)
        let portable = root.appendingPathComponent("portable"); try SafeFiles.directory(portable)
        let publication = try a.publish(env.id, to: portable), imported = try b.pull(from: publication)
        XCTAssertEqual(imported.enabledMods, ids.reversed()); XCTAssertEqual(b.state.mods.count, 2)
        XCTAssertEqual(try SafeFiles.regularFiles(b.overlayURL(imported)), first.hashes)
        try Data("must not export".utf8).write(to: a.packageURL(ids[0]).deletingLastPathComponent().appendingPathComponent("unexpected.txt"))
        XCTAssertThrowsError(try a.publish(env.id, to: portable))
    }
    func testHardLinksAndCaseConflictsRejected() throws {
        let source = root.appendingPathComponent("source"); try SafeFiles.directory(source)
        let file = source.appendingPathComponent("one"); try Data("synthetic".utf8).write(to: file)
        try FileManager.default.linkItem(at: file, to: source.appendingPathComponent("two"))
        XCTAssertThrowsError(try SafeFiles.regularFiles(source))
        let store = try LibraryStore(root: root.appendingPathComponent("workspace")), env = try store.create(name: "Test")
        var ids: [String] = []
        for name in ["Upper", "Lower"] {
            let folder = root.appendingPathComponent(name); try SafeFiles.directory(folder.appendingPathComponent("romfs"))
            try Data(name.utf8).write(to: folder.appendingPathComponent(name == "Upper" ? "romfs/Case" : "romfs/case"))
            ids.append(try store.importMod(folder).id)
        }
        try store.setMods(env.id, orderedIDs: ids); XCTAssertFalse(try store.plan(store.state.environments[0]).canDeploy)
    }
}
