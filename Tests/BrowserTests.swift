import GRDB
import XCTest
@testable import Torpido

final class BrowserTests: XCTestCase {
    func testAddressesSearchesAndHosts() {
        XCTAssertEqual(BrowserAddress.url(from: "https://m.youtube.com/watch?v=1")?.absoluteString, "https://m.youtube.com/watch?v=1")
        XCTAssertEqual(BrowserAddress.url(from: " youtube.com ")?.absoluteString, "https://youtube.com")
        XCTAssertEqual(BrowserAddress.url(from: "haber izle")?.absoluteString, "https://duckduckgo.com/?q=haber%20izle")
        XCTAssertEqual(BrowserAddress.url(from: "şarkı")?.host, "duckduckgo.com")
        XCTAssertNil(BrowserAddress.url(from: "   "))
    }

    func testBookmarkTogglesAndKeepsOrder() throws {
        let database = try AppDatabase.empty()
        let store = BookmarkStore(database: database)

        try store.toggle(url: URL(string: "https://m.youtube.com")!, title: "YouTube")
        try store.toggle(url: URL(string: "https://example.org/a")!, title: "")
        let names = try database.reader.read { try LibraryQueries.bookmarks($0) }.map(\.title)
        try store.toggle(url: URL(string: "https://m.youtube.com")!, title: "YouTube")
        let after = try database.reader.read { try LibraryQueries.bookmarks($0) }.map(\.title)

        XCTAssertEqual(names, ["YouTube", "example.org"])
        XCTAssertEqual(after, ["example.org"])
    }
}
