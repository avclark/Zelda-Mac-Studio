import XCTest
@testable import StudioCore
final class FoundationTests: XCTestCase {
    func testSchemaRoundTrip() throws { let state = LibraryState(); XCTAssertEqual(try SafeFiles.decode(LibraryState.self, SafeFiles.encode(state)).schema, 1) }
    func testRejectUnsafePaths() throws {
        for path in ["../escape", "/absolute", "a/../b", "a\\b", "a//b", "a:b", "a\nfile"] { XCTAssertThrowsError(try SafeFiles.safePath(path)) }
        XCTAssertNoThrow(try SafeFiles.safePath("romfs/Actor/test.bin"))
    }
}
