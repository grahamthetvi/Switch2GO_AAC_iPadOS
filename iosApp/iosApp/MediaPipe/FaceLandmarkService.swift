import Foundation
import AVFoundation
import UIKit
import Combine
import MediaPipeTasksVision
import VocableShared
 
/// Service for detecting face landmarks using MediaPipe.
/// This class wraps the MediaPipe FaceLandmarker for use with the gaze tracking system.
class FaceLandmarkService: NSObject, ObservableObject, IOSFaceLandmarkBridge {
    // MediaPipe face landmarker instance — mutated only on detectionQueue
    private var faceLandmarker: FaceLandmarker?
    private var isInitialized = false
    private var lastUseGpu = false  // saved for reinitialize()
 
    /// Current detected landmarks (478 points for full face mesh)
    @Published var currentLandmarks: [NormalizedLandmark]?
 
    /// Whether a face is currently being tracked
    @Published var isTracking = false
 
    /// Last detection timestamp
    @Published var lastTimestamp: Int = 0

    private let detectionQueue = DispatchQueue(label: "com.switch2go.mediapipe.detection")
    private static let detectionQueueKey = DispatchSpecificKey<UInt8>()
    private let detectionQueueContext: UInt8 = 1

    /// Retain only the pixel buffer from AVCapture's pool — never the CMSampleBuffer.
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestOrientation: UIImage.Orientation = .up
    private var latestFrameSize: CGSize = .zero
    private var pendingRequest = false
    private var isDetecting = false
    private var detectionStartTime: TimeInterval = 0
    private let detectionTimeout: TimeInterval = 0.4  // Max time to wait for MediaPipe callback
    private weak var detector: PlatformFaceLandmarkDetector?
 
    override init() {
        super.init()
        detectionQueue.setSpecific(key: Self.detectionQueueKey, value: detectionQueueContext)
    }
 
    /// Attach the Kotlin detector so results can be bridged back.
    func attachDetector(_ detector: PlatformFaceLandmarkDetector) {
        self.detector = detector
    }

    /// Initialize the MediaPipe FaceLandmarker.
    /// - Parameter useGpu: Whether to use GPU acceleration
    /// - Returns: true if initialization was successful
    func initialize(useGpu: Bool = false) -> Bool {
        // Confine landmarker lifecycle to detectionQueue (no cross-queue races with reinitialize).
        if DispatchQueue.getSpecific(key: Self.detectionQueueKey) != nil {
            return initializeOnQueue(useGpu: useGpu)
        }
        return detectionQueue.sync { initializeOnQueue(useGpu: useGpu) }
    }

    private func initializeOnQueue(useGpu: Bool) -> Bool {
        if isInitialized && lastUseGpu == useGpu && faceLandmarker != nil {
            pendingRequest = false
            isDetecting = false
            latestPixelBuffer = nil
            DebugLog.info("Reused existing FaceLandmarker (GPU: \(useGpu))", tag: "MediaPipe")
            return true
        }

        if faceLandmarker != nil {
            closeOnQueue()
        }

        lastUseGpu = useGpu
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil

        do {
            let modelPath: String
            if let path = Bundle.main.path(forResource: "face_landmarker", ofType: "task") {
                modelPath = path
            } else if let url = Bundle.main.url(forResource: "face_landmarker", withExtension: "task", subdirectory: "Resources") {
                modelPath = url.path
            } else {
                DebugLog.error("Could not find face_landmarker.task model in bundle", tag: "MediaPipe")
                DebugLog.error("Bundle path: \(Bundle.main.bundlePath)", tag: "MediaPipe")
                return false
            }
            DebugLog.info("Found model at: \(modelPath)", tag: "MediaPipe")
 
            let options = FaceLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numFaces = 1
            options.minFaceDetectionConfidence = 0.5
            options.minFacePresenceConfidence = 0.5
            options.minTrackingConfidence = 0.4
            options.outputFaceBlendshapes = false
            options.outputFacialTransformationMatrixes = true
 
            if useGpu {
                options.baseOptions.delegate = .GPU
            } else {
                options.baseOptions.delegate = .CPU
            }
 
            options.faceLandmarkerLiveStreamDelegate = self
 
            faceLandmarker = try FaceLandmarker(options: options)
            isInitialized = true
            DebugLog.info("Initialized successfully (GPU: \(useGpu))", tag: "MediaPipe")
            return true
 
        } catch {
            DebugLog.error("Failed to initialize: \(error)", tag: "MediaPipe")
            return false
        }
    }
 
    /// Process a camera frame for face detection.
    func detectAsync(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) {
        guard isInitialized, let faceLandmarker = faceLandmarker else {
            DebugLog.warn("Not initialized or landmarker is nil, skipping detection", tag: "MediaPipe")
            notifyDetectorNoFace()
            return
        }
 
        guard let image = try? MPImage(pixelBuffer: pixelBuffer, orientation: orientation) else {
            DebugLog.error("Failed to create MPImage from pixel buffer", tag: "MediaPipe")
            notifyDetectorNoFace()
            return
        }
        
        if AppSettings.shared.showDebugCameraPreview {
            DebugLog.debug("Sending \(Int(image.width))x\(Int(image.height)) image, orientation: \(orientation.rawValue)", tag: "MediaPipe")
        }
 
        let timestamp = Int(CACurrentMediaTime() * 1000)
 
        do {
            try faceLandmarker.detectAsync(image: image, timestampInMilliseconds: timestamp)
        } catch {
            DebugLog.error("detectAsync error: \(error)", tag: "MediaPipe")
            notifyDetectorNoFace()
        }
    }

    /// Store the latest frame pixel buffer and optionally trigger detection if requested.
    func updateLatestSampleBuffer(_ sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            // Retain CVPixelBuffer only — release the sample buffer back to the pool.
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                self.latestPixelBuffer = pixelBuffer
                self.latestFrameSize = CGSize(
                    width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer)
                )
            }
            self.latestOrientation = orientation
            self.triggerDetectionIfNeeded()
        }
    }

    /// Request a detection cycle for the latest frame.
    func requestDetection() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRequest = true
            self.triggerDetectionIfNeeded()
        }
    }

    private func triggerDetectionIfNeeded() {
        if isDetecting && (CACurrentMediaTime() - detectionStartTime) > detectionTimeout {
            DebugLog.warn("Detection timed out — resetting state", tag: "MediaPipe")
            isDetecting = false
        }

        guard pendingRequest, !isDetecting else { return }

        guard let pixelBuffer = latestPixelBuffer else {
            pendingRequest = false
            detector?.onNoFaceDetected()
            return
        }

        isDetecting = true
        detectionStartTime = CACurrentMediaTime()
        detectAsync(pixelBuffer: pixelBuffer, orientation: latestOrientation)
    }
 
    /// Reset processing state without closing the service.
    func resetProcessingState() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRequest = false
            self.isDetecting = false
            self.latestPixelBuffer = nil
            DebugLog.debug("Processing state reset for orientation change", tag: "MediaPipe")
        }
        DispatchQueue.main.async { [weak self] in
            self?.currentLandmarks = nil
            self?.isTracking = false
        }
    }

    /// Destroy and recreate the MediaPipe FaceLandmarker.
    func reinitialize() {
        let useGpu = lastUseGpu
        DebugLog.info("Reinitializing for new frame dimensions (GPU: \(useGpu))...", tag: "MediaPipe")

        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.closeOnQueue()
            let success = self.initializeOnQueue(useGpu: useGpu)
            DebugLog.log("Reinitialize: \(success ? "success" : "FAILED")", tag: "MediaPipe", level: success ? .info : .error)
        }
    }

    /// Release resources.
    func close() {
        if DispatchQueue.getSpecific(key: Self.detectionQueueKey) != nil {
            closeOnQueue()
            return
        }
        detectionQueue.sync { closeOnQueue() }
    }

    private func closeOnQueue() {
        faceLandmarker = nil
        isInitialized = false
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil
        latestFrameSize = .zero
        DispatchQueue.main.async {
            self.currentLandmarks = nil
            self.isTracking = false
        }
        DebugLog.debug("FaceLandmarkService closed", tag: "MediaPipe")
    }
}
 
// MARK: - FaceLandmarkerLiveStreamDelegate
extension FaceLandmarkService: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(
        _ faceLandmarker: FaceLandmarker,
        didFinishDetection result: FaceLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if let error = error {
            DebugLog.error("Delegate detection error: \(error)", tag: "MediaPipe")
            notifyDetectorNoFace()
            return
        }
 
        guard let result = result,
              let firstFace = result.faceLandmarks.first else {
            if AppSettings.shared.showDebugCameraPreview {
                DebugLog.warn("No face detected in frame", tag: "MediaPipe")
            }
            DispatchQueue.main.async {
                self.currentLandmarks = nil
                self.isTracking = false
            }
            notifyDetectorNoFace()
            return
        }
        
        if AppSettings.shared.showDebugCameraPreview && firstFace.count < 478 {
            DebugLog.warn("Face detected but missing irises (count: \(firstFace.count))", tag: "MediaPipe")
        }
 
        DispatchQueue.main.async {
            self.currentLandmarks = firstFace
            self.isTracking = true
            self.lastTimestamp = timestampInMilliseconds
        }

        notifyDetectorLandmarks(firstFace, timestamp: timestampInMilliseconds)
    }
}
 
// MARK: - Kotlin Bridge Helpers
private extension FaceLandmarkService {
    func notifyDetectorLandmarks(_ landmarks: [NormalizedLandmark], timestamp: Int) {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            guard let detector = self.detector else {
                self.pendingRequest = false
                self.isDetecting = false
                return
            }

            let width = Int32(self.latestFrameSize.width)
            let height = Int32(self.latestFrameSize.height)
            let landmarkArrays = landmarks.map { landmark in
                self.toKotlinFloatArray([landmark.x, landmark.y, landmark.z])
            }

            detector.onLandmarksDetectedRaw(
                landmarks: landmarkArrays,
                frameWidth: width,
                frameHeight: height,
                timestamp: Int64(timestamp)
            )

            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    func notifyDetectorNoFace() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.detector?.onNoFaceDetected()
            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    func toKotlinFloatArray(_ values: [Float]) -> KotlinFloatArray {
        let array = KotlinFloatArray(size: Int32(values.count))
        for (index, value) in values.enumerated() {
            array.set(index: Int32(index), value: value)
        }
        return array
    }
}
// MARK: - Landmark Index Constants
/// MediaPipe Face Mesh landmark indices for eye tracking.
struct FaceLandmarkIndices {
    // Left eye landmarks
    static let leftEyeOuter = 33
    static let leftEyeInner = 133
    static let leftEyeTop = 159
    static let leftEyeBottom = 145
    static let leftIris = 468
 
    // Right eye landmarks
    static let rightEyeOuter = 263
    static let rightEyeInner = 362
    static let rightEyeTop = 386
    static let rightEyeBottom = 374
    static let rightIris = 473
 
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
