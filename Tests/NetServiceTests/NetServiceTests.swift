import XCTest
import Dispatch
import Foundation
@testable import NetService

class NetServiceTests: XCTestCase, DNSSDNetServiceDelegate {
    var didAccept = false

    func testInitialiser() {
        let p = 1234
        let d = ""
        let t = "_test._tcp"
        let n = "TestMachine"
        let service = DNSSDNetService(domain: d, type: t, name: n, port: Int32(p))
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
        let service = DNSSDNetService(domain: d, type: t, name: n, port: Int32(p))
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

    func testListen() {
        let p = 2323
        let d = "local."
        let t = "_testtelnet._tcp."
        let n = "localhost"
        let service = DNSSDNetService(domain: d, type: t, name: n, port: Int32(p))
        service.delegate = self
        service.publish(options: [.listenForConnections])
        DispatchQueue.global().async {
            _ = NSData(contentsOf: URL(string: "http://\(n):\(p)/")!)
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        XCTAssertEqual(service.port, p)
        XCTAssertEqual(service.domain, d)
        XCTAssertEqual(service.type, t)
        XCTAssertEqual(service.name, n)
        XCTAssertEqual(service.lastError, 0)
        XCTAssertTrue(didAccept)
    }

    func netService(_ sender: DNSSDNetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        didAccept = true
        XCTAssert(inputStream is DNSSDNetServiceInputStream)
        XCTAssert(outputStream is DNSSDNetServiceOutputStream)
    }

    func netService(_ sender: DNSSDNetService, didNotPublish errorDict: DNSSDNetService.ErrorDictionary) {
        XCTFail(errorDict.description)
    }

    func netService(_ sender: DNSSDNetService, didNotResolve errorDict: DNSSDNetService.ErrorDictionary) {
        XCTFail(errorDict.description)
    }

    static var allTests : [(String, (NetServiceTests) -> () throws -> Void)] {
        return [
            ("testInitialiser", testInitialiser),
            ("testPublish",     testPublish),
            ("testListen",      testListen),
        ]
    }
}
