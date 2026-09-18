import XCTest
@testable import GateCore

final class PermanentWebPolicyTests: XCTestCase {
    func testXHostsIncludeMainLegacyShortlinkAndMedia() {
        let domains = Set(GatePermanentWebPolicy.domains)
        for domain in ["x.com", "twitter.com", "t.co", "mobile.twitter.com", "pro.x.com", "video.twimg.com", "pbs.twimg.com"] {
            XCTAssertTrue(domains.contains(domain))
        }
        XCTAssertEqual(domains.count, GatePermanentWebPolicy.domains.count)
        XCTAssertLessThanOrEqual(domains.count, 50)
        XCTAssertFalse(domains.contains("example.com"))
        XCTAssertFalse(domains.contains("whatsapp.com"))
        XCTAssertTrue(domains.allSatisfy { !$0.contains("/") && !$0.contains("*") })
    }
}
