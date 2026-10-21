import XCTest
@testable import Torpido

final class M3UParserTests: XCTestCase {
    func testReadsAttributesNameAndURL() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 tvg-id="trt1.tr" tvg-logo="https://logo.example/trt1.png" group-title="Ulusal",TRT 1
        http://stream.example/trt1.m3u8
        """

        let entries = try M3UParser.parse(text)

        XCTAssertEqual(entries, [PlaylistEntry(
            name: "TRT 1",
            group: "Ulusal",
            logoURL: URL(string: "https://logo.example/trt1.png"),
            tvgID: "trt1.tr",
            streamURL: URL(string: "http://stream.example/trt1.m3u8")!
        )])
    }

    func testCommaInsideQuotedAttributeDoesNotSplitTheName() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 group-title="Haber, Ekonomi",Kanal A, HD
        http://s.example/a
        """

        let entry = try XCTUnwrap(M3UParser.parse(text).first)

        XCTAssertEqual(entry.group, "Haber, Ekonomi")
        XCTAssertEqual(entry.name, "Kanal A, HD")
    }

    func testRejectsTextWithoutHeader() {
        XCTAssertThrowsError(try M3UParser.parse("<html>Not found</html>")) { error in
            XCTAssertEqual(error as? PlaylistError, .notAPlaylist)
        }
    }

    func testEmptyTextIsNotAPlaylist() {
        XCTAssertThrowsError(try M3UParser.parse(""))
    }

    func testHandlesBOMAndCRLF() throws {
        let text = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1,Bir\r\nhttp://s.example/1\r\n"

        let entries = try M3UParser.parse(text)

        XCTAssertEqual(entries.map(\.name), ["Bir"])
    }

    func testEXTGRPSetsGroupWhenGroupTitleIsMissing() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1,Belgesel 1
        #EXTGRP:Belgesel
        http://s.example/b1
        """

        XCTAssertEqual(try M3UParser.parse(text).first?.group, "Belgesel")
    }

    func testBareURLGetsANameFromItsPath() throws {
        let text = """
        #EXTM3U
        http://s.example/live/haber24.ts
        """

        XCTAssertEqual(try M3UParser.parse(text).first?.name, "haber24")
    }

    func testIgnoresOtherDirectivesBlankLinesAndNonURLs() throws {
        let text = """
        #EXTM3U x-tvg-url="http://epg.example"

        #EXTVLCOPT:http-user-agent=Foo
        #EXTINF:-1,Bir
        http://s.example/1
        not a url
        #EXTINF:-1,İki
        http://s.example/2
        """

        XCTAssertEqual(try M3UParser.parse(text).map(\.name), ["Bir", "İki"])
    }

    func testEmptyAttributeValuesBecomeNil() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1 tvg-logo="" group-title="",Bir
        http://s.example/1
        """

        let entry = try XCTUnwrap(M3UParser.parse(text).first)

        XCTAssertNil(entry.logoURL)
        XCTAssertNil(entry.group)
    }
}
