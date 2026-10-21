import XCTest
@testable import StudioCore
final class PortableTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try SafeFiles.directory(root) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func setup() throws -> (LibraryStore, Adventure, URL) {
        let a = try LibraryStore(root: root.appendingPathComponent("a")), env = try a.create(name: "Main")
        try a.writeManagedSave(env.id, path: "slot", data: Data("synthetic-save".utf8))
        _ = try a.snapshot(env.id, label: "Save checkpoint")
        let folder = root.appendingPathComponent("portable"); try SafeFiles.directory(folder)
        return (a, a.state.environments[0], folder)
    }
    func testRoundTripAndDivergentBranchesRetained() throws {
        let (a, env, folder) = try setup(), b = try LibraryStore(root: root.appendingPathComponent("b"))
        let publication = try a.publish(env.id, to: folder, includeSaveSnapshots: true)
        let imported = try b.pull(from: publication)
        XCTAssertEqual(try SafeFiles.regularFiles(a.revisionURL(env)), try SafeFiles.regularFiles(b.revisionURL(imported)))
        XCTAssertEqual(b.state.snapshots.count, 1)
        try b.writeManagedSave(imported.id, path: "slot", data: Data("branch-b".utf8))
        let local = b.state.environments[0], again = try b.pull(from: publication)
        XCTAssertNotEqual(again.id, local.id); XCTAssertEqual(again.parentID, local.id)
        XCTAssertEqual(b.state.environments.count, 2)
        XCTAssertEqual(try String(contentsOf: b.savesURL(local).appendingPathComponent("slot")), "branch-b")
        XCTAssertEqual(try String(contentsOf: b.savesURL(again).appendingPathComponent("slot")), "synthetic-save")
        let json = try String(contentsOf: publication.appendingPathComponent("manifest.json"))
        XCTAssertFalse(json.contains(root.path)); XCTAssertFalse(json.contains("prod.keys"))
    }
    func testIncompleteCorruptAndInterruptedImportsRejected() throws {
        let (a, env, folder) = try setup(), b = try LibraryStore(root: root.appendingPathComponent("b"))
        let publication = try a.publish(env.id, to: folder, includeSaveSnapshots: true)
        let marker = publication.appendingPathComponent("COMPLETE"), markerData = try Data(contentsOf: marker)
        try FileManager.default.removeItem(at: marker)
        XCTAssertThrowsError(try b.pull(from: publication)); XCTAssertTrue(b.state.environments.isEmpty)
        try markerData.write(to: marker)
        b.beforeCommit = { throw StudioError.invalid("Injected interrupted import") }
        XCTAssertThrowsError(try b.pull(from: publication)); XCTAssertTrue(try LibraryStore(root: b.root).state.environments.isEmpty)
        b.beforeCommit = nil
        try Data("corrupt".utf8).write(to: publication.appendingPathComponent("payload/revisions/\(env.revision.uuidString)/saves/slot"))
        XCTAssertThrowsError(try b.pull(from: publication)); XCTAssertTrue(b.state.environments.isEmpty)
    }
    func testDefaultExportExcludesSavesAndWorkspaceOverlap() throws {
        let (a, env, folder) = try setup(), b = try LibraryStore(root: root.appendingPathComponent("b"))
        XCTAssertThrowsError(try a.publish(env.id, to: a.root))
        let publication = try a.publish(env.id, to: folder)
        let imported = try b.pull(from: publication)
        XCTAssertTrue(try SafeFiles.regularFiles(b.savesURL(imported)).isEmpty)
        XCTAssertTrue(b.state.snapshots[0].manifest.isEmpty)
    }
}
