import Foundation

/// Wire format between the broadcast extension (sender) and the app (receiver).
///
/// The extension connects to the app over loopback TCP and sends a stream of
/// frames. Each frame is a 4-byte big-endian length followed by that many bytes
/// of JPEG data. Loopback keeps everything on the phone and needs no App Group.
enum MirrorLink {
    static let host = "127.0.0.1"
    static let port: UInt16 = 48_621
    static let headerSize = 4
    /// A 1280px JPEG is well under 1 MB; anything near this is a corrupt stream.
    static let maxFrameBytes = 8 * 1024 * 1024

    static func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).bigEndian
        var framed = Data(bytes: &length, count: headerSize)
        framed.append(payload)
        return framed
    }
}

enum FrameDecoderError: Error, Equatable {
    case frameTooLarge(Int)
}

/// Reassembles frames from arbitrarily sized TCP chunks.
struct FrameDecoder {
    private var buffer = Data()

    var bufferedByteCount: Int { buffer.count }

    /// Appends a chunk and returns every frame it completed, in order.
    mutating func append(_ chunk: Data) throws -> [Data] {
        buffer.append(chunk)
        var frames: [Data] = []
        while buffer.count >= MirrorLink.headerSize {
            let length = buffer.prefix(MirrorLink.headerSize)
                .reduce(0) { ($0 << 8) | Int($1) }
            guard length <= MirrorLink.maxFrameBytes else {
                buffer.removeAll()
                throw FrameDecoderError.frameTooLarge(length)
            }
            let end = MirrorLink.headerSize + length
            guard buffer.count >= end else { break }
            frames.append(Data(buffer[buffer.startIndex + MirrorLink.headerSize ..< buffer.startIndex + end]))
            buffer = Data(buffer.dropFirst(end))
        }
        return frames
    }
}
