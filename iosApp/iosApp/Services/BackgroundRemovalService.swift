import UIKit
import CoreImage
import Vision

/// Service that removes backgrounds from images using Apple's Vision
/// person/salient object segmentation (available on iOS 17+),
/// with a CoreML DeepLabV3 fallback for earlier OS versions.
class BackgroundRemovalService {
    static let shared = BackgroundRemovalService()
    private let ciContext = CIContext()

    private init() {}

    /// Remove the background from an image, returning an image with a transparent background.
    /// Uses VNGenerateForegroundInstanceMaskRequest on iOS 17+ for best quality,
    /// otherwise falls back to a simpler saliency-based approach.
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw BackgroundRemovalError.invalidImage
        }

        if #available(iOS 17.0, *) {
            return try await removeBackgroundWithVision(cgImage: cgImage, orientation: image.imageOrientation)
        } else {
            return try removeBackgroundWithSaliency(cgImage: cgImage, orientation: image.imageOrientation)
        }
    }

    // MARK: - iOS 17+ Vision Foreground Mask

    @available(iOS 17.0, *)
    private func removeBackgroundWithVision(cgImage: CGImage, orientation: UIImage.Orientation) async throws -> UIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw BackgroundRemovalError.segmentationFailed
        }

        let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        let originalImage = CIImage(cgImage: cgImage)

        let filter = CIFilter(name: "CIBlendWithMask")!
        filter.setValue(originalImage, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: originalImage.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(maskImage.transformed(by: CGAffineTransform(
            scaleX: originalImage.extent.width / maskImage.extent.width,
            y: originalImage.extent.height / maskImage.extent.height
        )), forKey: kCIInputMaskImageKey)

        guard let outputImage = filter.outputImage,
              let outputCG = ciContext.createCGImage(outputImage, from: originalImage.extent) else {
            throw BackgroundRemovalError.segmentationFailed
        }

        return UIImage(cgImage: outputCG, scale: 1.0, orientation: orientation)
    }

    // MARK: - Fallback: Saliency-based segmentation

    private func removeBackgroundWithSaliency(cgImage: CGImage, orientation: UIImage.Orientation) throws -> UIImage {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw BackgroundRemovalError.segmentationFailed
        }

        let maskCI = CIImage(cvPixelBuffer: result.pixelBuffer)
        let originalImage = CIImage(cgImage: cgImage)

        let scaledMask = maskCI.transformed(by: CGAffineTransform(
            scaleX: originalImage.extent.width / maskCI.extent.width,
            y: originalImage.extent.height / maskCI.extent.height
        ))

        let thresholdFilter = CIFilter(name: "CIColorClamp")!
        thresholdFilter.setValue(scaledMask, forKey: kCIInputImageKey)
        thresholdFilter.setValue(CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0.3), forKey: "inputMinComponents")
        thresholdFilter.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")

        let processedMask = thresholdFilter.outputImage ?? scaledMask

        let blendFilter = CIFilter(name: "CIBlendWithMask")!
        blendFilter.setValue(originalImage, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage(color: .clear).cropped(to: originalImage.extent), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(processedMask, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage,
              let outputCG = ciContext.createCGImage(outputImage, from: originalImage.extent) else {
            throw BackgroundRemovalError.segmentationFailed
        }

        return UIImage(cgImage: outputCG, scale: 1.0, orientation: orientation)
    }
}

// MARK: - Error

enum BackgroundRemovalError: LocalizedError {
    case invalidImage
    case segmentationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed."
        case .segmentationFailed:
            return "Background removal failed. Try a different image."
        }
    }
}
