import XCTest
import Foundation
@testable import NetServiceTests

setenv("AVAHI_COMPAT_NOWARN", "1", 1)

XCTMain([
     testCase(NetServiceTests.allTests),
])
