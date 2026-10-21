import XCTest
@testable import StudioCore
final class RuntimeTests: XCTestCase {
    func testReadinessNeverPromotesCorruptGameOrPretendsLaunch() throws {
        for backend in Backend.allCases {
            let adapter = GuardedRuntimeAdapter(backend)
            XCTAssertFalse(adapter.readiness(osMajor: 14, knownCorruptBase: true).canLaunch)
            XCTAssertFalse(adapter.readiness(osMajor: 26, knownCorruptBase: false).canLaunch)
            XCTAssertThrowsError(try adapter.launch(environment: Adventure(name: "Test")))
        }
        XCTAssertTrue(GuardedRuntimeAdapter(.macNative).readiness(osMajor: 14).status.contains("OS upgrade"))
    }
    func testOwnedProcessMonitoringAndGracefulTermination() throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/sleep"); process.arguments = ["10"]
        try process.run()
        let registry = RuntimeProcessRegistry(), id = UUID(); registry.track(process, for: id)
        XCTAssertTrue(registry.isActive(id)); registry.terminate(id); process.waitUntilExit(); XCTAssertFalse(registry.isActive(id))
    }
    func testDiagnosticsAllowListExcludesPrivateFields() throws {
        var state = LibraryState(), env = Adventure(name: "/private/name")
        env.notes = "SECRET NOTE"; state.environments = [env]
        let report = Diagnostics.report(state)
        XCTAssertFalse(report.contains("SECRET NOTE")); XCTAssertFalse(report.contains("/private/name"))
    }
}
