import Foundation
import AVFoundation
import UIKit
// Note: Import MediaPipeTasksVision after installing via CocoaPods
// import MediaPipeTasksVision

/// Service for detecting face landmarks using MediaPipe.
/// This class wraps the MediaPipe FaceLandmarker for use with the gaze tracking system.
class FaceLandmarkService: ObservableObject {
    // MediaPipe face landmarker instance
    // Uncomment after adding MediaPipe via CocoaPods:
    // private var faceLandmarker: FaceLandmarker?

    private var isInitialized = false

    /// Current detected landmarks (478 points for full face mesh)
    @Published var currentLandmarks: [Any]?

    /// Whether a face is currently being tracked
    @Published var isTracking = false

    /// Last detection timestamp
    @Published var lastTimestamp: Int = 0

    /// Initialize the MediaPipe FaceLandmarker.
    /// - Parameter useGpu: Whether to use GPU acceleration
    /// - Returns: true if initialization was successful
    func initialize(useGpu: Bool = false) -> Bool {
        do {
            // Get the model file from the app bundle
            guard let modelPath = Bundle.main.path(
                forResource: "face_landmarker",
                ofType: "task"
            ) else {
                print("[FaceLandmarkService] ERROR: Could not find face_landmarker.task model")
                print("[FaceLandmarkService] Download from: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task")
                return false
            }

            // TODO: Uncomment after adding MediaPipe via CocoaPods
            /*
            // Configure options
            let options = FaceLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5
            options.minFacePresenceConfidence = 0.5
            options.minTrackingConfidence = 0.5
            options.outputFaceBlendshapes = false
            options.outputFacialTransformationMatrixes = false

            // Set delegate based on GPU preference
            if useGpu {
                options.baseOptions.delegate = .GPU
            } else {
                options.baseOptions.delegate = .CPU
            }

            // Set result callback
            options.faceLandmarkerLiveStreamDelegate = self

            faceLandmarker = try FaceLandmarker(options: options)
            */

            isInitialized = true
            print("[FaceLandmarkService] Initialized successfully (GPU: \(useGpu))")
            return true

        } catch {
            print("[FaceLandmarkService] ERROR: Failed to initialize: \(error)")
            return false
        }
    }

    /// Process a camera frame for face detection.
    /// - Parameters:
    ///   - sampleBuffer: The camera sample buffer
    ///   - orientation: Image orientation
    func detectAsync(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        guard isInitialized else { return }

        // TODO: Uncomment after adding MediaPipe via CocoaPods
        /*
        guard let faceLandmarker = faceLandmarker else { return }

        // Convert sample buffer to MPImage
        guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else {
            print("[FaceLandmarkService] Failed to create MPImage")
            return
        }

        // Get timestamp in milliseconds
        let timestamp = Int(CACurrentMediaTime() * 1000)

        do {
            try faceLandmarker.detectAsync(image: image, timestampInMilliseconds: timestamp)
        } catch {
            print("[FaceLandmarkService] Detection error: \(error)")
        }
        */
    }

    /// Release resources.
    func close() {
        // faceLandmarker = nil
        isInitialized = false
        currentLandmarks = nil
        isTracking = false
        print("[FaceLandmarkService] Closed")
    }
}

// MARK: - FaceLandmarkerLiveStreamDelegate
// TODO: Uncomment after adding MediaPipe via CocoaPods
/*
extension FaceLandmarkService: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(
        _ faceLandmarker: FaceLandmarker,
        didFinishDetection result: FaceLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if let error = error {
            print("[FaceLandmarkService] Detection error: \(error)")
            return
        }

        guard let result = result,
              let firstFace = result.faceLandmarks.first else {
            DispatchQueue.main.async {
                self.currentLandmarks = nil
                self.isTracking = false
            }
            return
        }

        DispatchQueue.main.async {
            self.currentLandmarks = firstFace
            self.isTracking = true
            self.lastTimestamp = timestampInMilliseconds
        }
    }
}
*/

// MARK: - Landmark Index Constants
/// MediaPipe Face Mesh landmark indices for eye tracking.
/// Reference: https://github.com/google/mediapipe/blob/master/mediapipe/modules/face_geometry/data/canonical_face_model_uv_visualization.png
struct FaceLandmarkIndices {
    // Left eye landmarks
    static let leftEyeOuter = 33
    static let leftEyeInner = 133
    static let leftEyeTop = 159
    static let leftEyeBottom = 145
    static let leftIris = 468  // Center of left iris

    // Right eye landmarks
    static let rightEyeOuter = 263
    static let rightEyeInner = 362
    static let rightEyeTop = 386
    static let rightEyeBottom = 374
    static let rightIris = 473  // Center of right iris

    // Iris landmarks (detailed)
    static let leftIrisCenter = 468
    static let leftIrisTop = 469
    static let leftIrisRight = 470
    static let leftIrisBottom = 471
    static let leftIrisLeft = 472

    static let rightIrisCenter = 473
    static let rightIrisTop = 474
    static let rightIrisRight = 475
    static let rightIrisBottom = 476
    static let rightIrisLeft = 477

    // Face orientation landmarks
    static let noseTip = 1
    static let leftCheek = 234
    static let rightCheek = 454
    static let chin = 152
    static let forehead = 10
}
