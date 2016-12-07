import XCTest
@testable import NetService

class NetServiceTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(NetService().text, "Hello, World!")
    }


    static var allTests : [(String, (NetServiceTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
