import XCTest
@testable import Torpido

final class FrameDecoderTests: XCTestCase {
    func testFrameRoundTripsThroughDecoder() throws {
        var decoder = FrameDecoder()
        let payload = Data("perde".utf8)

        let frames = try decoder.append(MirrorLink.frame(payload))

        XCTAssertEqual(frames, [payload])
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }

    func testHeaderIsBigEndianLength() {
        let framed = MirrorLink.frame(Data(count: 258))

        XCTAssertEqual(Array(framed.prefix(4)), [0, 0, 1, 2])
        XCTAssertEqual(framed.count, 262)
    }

    func testFrameSplitAcrossChunksIsReassembled() throws {
        var decoder = FrameDecoder()
        let payload = Data((0..<100).map { UInt8($0) })
        let framed = MirrorLink.frame(payload)

        let first = try decoder.append(framed.prefix(3))
        let second = try decoder.append(framed.dropFirst(3).prefix(50))
        let third = try decoder.append(framed.dropFirst(53))

        XCTAssertTrue(first.isEmpty)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(third, [payload])
    }

    func testSeveralFramesInOneChunkComeOutInOrder() throws {
        var decoder = FrameDecoder()
        let a = Data("a".utf8), b = Data("bb".utf8), c = Data()
        var chunk = MirrorLink.frame(a)
        chunk.append(MirrorLink.frame(b))
        chunk.append(MirrorLink.frame(c))

        let frames = try decoder.append(chunk)

        XCTAssertEqual(frames, [a, b, c])
    }

    func testTrailingPartialFrameStaysBuffered() throws {
        var decoder = FrameDecoder()
        var chunk = MirrorLink.frame(Data("ok".utf8))
        chunk.append(MirrorLink.frame(Data("later".utf8)).prefix(6))

        let frames = try decoder.append(chunk)

        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(decoder.bufferedByteCount, 6)
    }

    func testOversizedLengthThrowsAndClearsBuffer() {
        var decoder = FrameDecoder()
        let tooBig = UInt32(MirrorLink.maxFrameBytes + 1).bigEndian
        let header = withUnsafeBytes(of: tooBig) { Data($0) }

        XCTAssertThrowsError(try decoder.append(header)) { error in
            XCTAssertEqual(error as? FrameDecoderError, .frameTooLarge(MirrorLink.maxFrameBytes + 1))
        }
        XCTAssertEqual(decoder.bufferedByteCount, 0)
    }
}
