import XCTest
import Foundation
@testable import NetService

class NetServiceTests: XCTestCase {
    func testInitialiser() {
        let p = 1234
        let d = ""
        let t = "_test._tcp"
        let n = "TestMachine"
        let service = SwiftNetService(domain: d, type: t, name: n, port: Int32(p))
        XCTAssertEqual(service.port, p)
        XCTAssertEqual(service.domain, d)
        XCTAssertEqual(service.type, t)
        XCTAssertEqual(service.name, n)
        XCTAssertEqual(service.adresses, [])
    }

    func testPublish() {
        let p = 1234
        let d = "local."
        let t = "_test._tcp."
        let n = "TestMachine"
        let service = SwiftNetService(domain: d, type: t, name: n, port: Int32(p))
        service.schedule(in: RunLoop.current)
        service.publish()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        service.fire(service.timer)
        XCTAssertEqual(service.port, p)
        XCTAssertEqual(service.domain, d)
        XCTAssertEqual(service.type, t)
        XCTAssertEqual(service.name, n)
        XCTAssertEqual(service.lastError, 0)
    }


    static var allTests : [(String, (NetServiceTests) -> () throws -> Void)] {
        return [
            ("testInitialiser", testInitialiser),
            ("testPublish",     testPublish),
        ]
    }
}
