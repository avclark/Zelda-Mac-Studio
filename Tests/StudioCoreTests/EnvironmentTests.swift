import XCTest
@testable import StudioCore
final class EnvironmentTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    override func tearDownWithError() throws { if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) } }
    func testCreatePersistenceAndCloneSaveIsolation() throws {
        let store = try LibraryStore(root: root)
        let a = try store.create(name: "Main")
        try store.writeManagedSave(a.id, path: "slot.dat", data: Data("origin".utf8))
        let original = store.state.environments[0], before = try SafeFiles.regularFiles(store.revisionURL(original))
        let b = try store.clone(a.id, name: "Experiment", includeSaves: true)
        try store.writeManagedSave(b.id, path: "slot.dat", data: Data("changed".utf8))
        XCTAssertNotEqual(store.savesURL(original), store.savesURL(b))
        XCTAssertEqual(try SafeFiles.regularFiles(store.revisionURL(original)), before)
        try store.setTrashed(b.id, true)
        XCTAssertEqual(try SafeFiles.regularFiles(store.revisionURL(original)), before)
        let reopened = try LibraryStore(root: root)
        XCTAssertEqual(reopened.state.environments.count, 2)
        XCTAssertTrue(reopened.state.environments[1].trashed)
        try reopened.setTrashed(b.id, false)
        XCTAssertFalse(reopened.state.environments[1].trashed)
        let fresh = try reopened.clone(a.id, name: "Fresh", includeSaves: false)
        XCTAssertTrue(try SafeFiles.regularFiles(reopened.savesURL(fresh)).isEmpty)
    }
    func testSnapshotRestoreAndRollbackOnFailure() throws {
        let store = try LibraryStore(root: root), env = try store.create(name: "Main")
        try store.writeManagedSave(env.id, path: "slot.dat", data: Data("before".utf8))
        let snap = try store.snapshot(env.id, label: "Known good")
        try store.writeManagedSave(env.id, path: "slot.dat", data: Data("after".utf8))
        let after = store.state.environments[0]
        store.beforeCommit = { throw StudioError.invalid("Injected commit failure") }
        XCTAssertThrowsError(try store.restore(snap.id))
        XCTAssertEqual(try LibraryStore(root: root).state.environments[0], after)
        store.beforeCommit = nil
        try store.restore(snap.id)
        XCTAssertEqual(try SafeFiles.regularFiles(store.revisionURL(store.state.environments[0])), snap.manifest)
        XCTAssertEqual(store.state.snapshots.count, 2)
    }
    func testRunningEnvironmentRefusesMutation() throws {
        let store = try LibraryStore(root: root), env = try store.create(name: "Main")
        store.isRuntimeActive = { $0 == env.id }
        XCTAssertThrowsError(try store.clone(env.id, name: "Clone", includeSaves: true))
        XCTAssertThrowsError(try store.snapshot(env.id, label: "Busy"))
        XCTAssertThrowsError(try store.setTrashed(env.id, true))
        XCTAssertThrowsError(try store.update(env.id, name: "Changed"))
    }
    func testCorruptSnapshotCannotRestore() throws {
        let store = try LibraryStore(root: root), env = try store.create(name: "Main")
        try store.writeManagedSave(env.id, path: "slot", data: Data("ok".utf8))
        let snap = try store.snapshot(env.id, label: "Snapshot")
        try Data("corrupt".utf8).write(to: store.savesURL(snap.environment).appendingPathComponent("slot"))
        XCTAssertThrowsError(try store.restore(snap.id))
    }
    func testUnsupportedSchemaAndUnrelatedFolderRejected() throws {
        let store = try LibraryStore(root: root)
        var bad = store.state; bad.schema = 999
        try SafeFiles.encode(bad).write(to: root.appendingPathComponent("catalog.json"))
        XCTAssertThrowsError(try LibraryStore(root: root))
        let other = root.appendingPathComponent("unrelated"); try SafeFiles.directory(other)
        try Data().write(to: other.appendingPathComponent("user-file"))
        XCTAssertThrowsError(try LibraryStore(root: other))
    }
}
