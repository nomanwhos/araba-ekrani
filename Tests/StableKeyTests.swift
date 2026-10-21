import XCTest
@testable import Torpido

final class StableKeyTests: XCTestCase {
    private func entry(_ name: String, group: String? = nil, tvg: String? = nil) -> PlaylistEntry {
        PlaylistEntry(name: name, group: group, logoURL: nil, tvgID: tvg, streamURL: URL(string: "http://s.example/x")!)
    }

    func testFoldHandlesTurkishCaseAndAccents() {
        XCTAssertEqual(TurkishFold.fold("İSTANBUL Çocuk  TV"), "istanbul cocuk tv")
        XCTAssertEqual(TurkishFold.fold("KIZILAY ışık"), "kizilay isik")
        XCTAssertEqual(TurkishFold.fold("Gül Şöyle Ğ"), "gul soyle g")
    }

    func testSameEntryGivesSameKeyAcrossRefreshes() {
        var first = StableKeyMaker()
        var second = StableKeyMaker()

        XCTAssertEqual(first.key(for: entry("Haber 24", group: "Haber")),
                       second.key(for: entry("HABER 24", group: "haber")))
    }

    func testTvgIDWinsOverName() {
        var maker = StableKeyMaker()

        XCTAssertEqual(maker.key(for: entry("TRT 1 HD", group: "Ulusal", tvg: "trt1.tr")), "tvg:trt1.tr|ulusal")
    }

    func testDuplicatesGetCountedSuffixInOrder() {
        var maker = StableKeyMaker()

        let keys = (0..<3).map { _ in maker.key(for: entry("Kanal", group: "A")) }

        XCTAssertEqual(keys, ["name:kanal|a", "name:kanal|a#2", "name:kanal|a#3"])
    }

    func testSameNameInDifferentGroupsIsNotADuplicate() {
        var maker = StableKeyMaker()

        XCTAssertEqual(maker.key(for: entry("Kanal", group: "A")), "name:kanal|a")
        XCTAssertEqual(maker.key(for: entry("Kanal", group: "B")), "name:kanal|b")
    }
}
