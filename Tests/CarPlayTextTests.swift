import XCTest
@testable import Torpido

final class CarPlayTextTests: XCTestCase {
    func testCleanNameDropsQualityAndScheduleTags() {
        XCTAssertEqual(CarPlayText.cleanName("A Haber (1080p)"), "A Haber")
        XCTAssertEqual(CarPlayText.cleanName("360 (720p) [Not 24/7]"), "360")
        XCTAssertEqual(CarPlayText.cleanName("TRT 1 (1440p)"), "TRT 1")
        XCTAssertEqual(CarPlayText.cleanName("beIN Sports 3 Turk"), "beIN Sports 3 Turk")
    }

    func testCleanNameKeepsNamesThatAreOnlyTags() {
        XCTAssertEqual(CarPlayText.cleanName("[Test]"), "[Test]")
    }
}
