import Foundation
import CoreImage
import CoreVideo
import ImageIO

/// Turns captured screen buffers into small upright JPEGs.
final class FrameEncoder {
    /// Long edge in pixels. Landscape video then reaches the car display near
    /// its native width while a JPEG stays well under 1 MB.
    private static let maxDimension: CGFloat = 1600
    private static let quality: CGFloat = 0.6

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    func jpeg(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Data? {
        let upright = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let longEdge = max(upright.extent.width, upright.extent.height)
        let scale = min(1, Self.maxDimension / longEdge)
        let scaled = upright.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.jpegRepresentation(
            of: scaled,
            colorSpace: colorSpace,
            options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): Self.quality]
        )
    }
}
