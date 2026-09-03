import Foundation
import AVFoundation
import UIKit
import Combine
import MediaPipeTasksVision

/// MediaPipe PoseLandmarker for upper-body / arm pose detection.
final class PoseLandmarkService: NSObject, ObservableObject {
    typealias PoseResultHandler = ([LandmarkPoint]) -> Void
    typealias NoPoseHandler = () -> Void

    private var poseLandmarker: PoseLandmarker?
    private var isInitialized = false
    private var lastUseGpu = false

    @Published private(set) var currentLandmarks: [LandmarkPoint] = []
    @Published private(set) var isTracking = false

    private let detectionQueue = DispatchQueue(label: "com.switch2go.mediapipe.pose")
    private static let detectionQueueKey = DispatchSpecificKey<UInt8>()
    private let detectionQueueContext: UInt8 = 1
    /// Retain only the pixel buffer — never the CMSampleBuffer from AVCapture's pool.
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestOrientation: UIImage.Orientation = .up
    private var pendingRequest = false
    private var isDetecting = false
    private var detectionStartTime: TimeInterval = 0
    private let detectionTimeout: TimeInterval = 0.4

    var onPoseDetected: PoseResultHandler?
    var onNoPoseDetected: NoPoseHandler?

    override init() {
        super.init()
        detectionQueue.setSpecific(key: Self.detectionQueueKey, value: detectionQueueContext)
    }

    func initialize(useGpu: Bool = false) -> Bool {
        if DispatchQueue.getSpecific(key: Self.detectionQueueKey) != nil {
            return initializeOnQueue(useGpu: useGpu)
        }
        return detectionQueue.sync { initializeOnQueue(useGpu: useGpu) }
    }

    private func initializeOnQueue(useGpu: Bool) -> Bool {
        if isInitialized && lastUseGpu == useGpu && poseLandmarker != nil {
            pendingRequest = false
            isDetecting = false
            latestPixelBuffer = nil
            DebugLog.info("Reused existing PoseLandmarker (GPU: \(useGpu))", tag: "MediaPipe")
            return true
        }

        if poseLandmarker != nil {
            closeOnQueue()
        }

        lastUseGpu = useGpu
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil

        do {
            guard let modelPath = Self.modelPath() else {
                DebugLog.error("Could not find pose_landmarker_lite.task model in bundle", tag: "MediaPipe")
                return false
            }

            let options = PoseLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numPoses = 1
            options.baseOptions.delegate = useGpu ? .GPU : .CPU
            options.poseLandmarkerLiveStreamDelegate = self

            poseLandmarker = try PoseLandmarker(options: options)
            isInitialized = true
            DebugLog.info("PoseLandmarker initialized (GPU: \(useGpu))", tag: "MediaPipe")
            return true
        } catch {
            DebugLog.error("Failed to initialize PoseLandmarker: \(error)", tag: "MediaPipe")
            return false
        }
    }

    func updateLatestSampleBuffer(_ sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                self.latestPixelBuffer = pixelBuffer
            }
            self.latestOrientation = orientation
            self.triggerDetectionIfNeeded()
        }
    }

    func requestDetection() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRequest = true
            self.triggerDetectionIfNeeded()
        }
    }

    func resetProcessingState() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRequest = false
            self.isDetecting = false
            self.latestPixelBuffer = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.currentLandmarks = []
            self?.isTracking = false
        }
    }

    func reinitialize() {
        let useGpu = lastUseGpu
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.closeOnQueue()
            let success = self.initializeOnQueue(useGpu: useGpu)
            DebugLog.log("PoseLandmarker reinitialize: \(success ? "success" : "FAILED")", tag: "MediaPipe", level: success ? .info : .error)
        }
    }

    func close() {
        if DispatchQueue.getSpecific(key: Self.detectionQueueKey) != nil {
            closeOnQueue()
            return
        }
        detectionQueue.sync { closeOnQueue() }
    }

    private func closeOnQueue() {
        poseLandmarker = nil
        isInitialized = false
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil
        DispatchQueue.main.async { [weak self] in
            self?.currentLandmarks = []
            self?.isTracking = false
        }
    }

    private func triggerDetectionIfNeeded() {
        if isDetecting && (CACurrentMediaTime() - detectionStartTime) > detectionTimeout {
            DebugLog.warn("Pose detection timed out — resetting state", tag: "MediaPipe")
            isDetecting = false
        }

        guard pendingRequest, !isDetecting else { return }

        guard let pixelBuffer = latestPixelBuffer else {
            pendingRequest = false
            notifyNoPose()
            return
        }

        guard isInitialized, let poseLandmarker else {
            notifyNoPose()
            return
        }

        guard let image = try? MPImage(pixelBuffer: pixelBuffer, orientation: latestOrientation) else {
            notifyNoPose()
            return
        }

        isDetecting = true
        detectionStartTime = CACurrentMediaTime()
        let timestamp = Int(CACurrentMediaTime() * 1000)

        do {
            try poseLandmarker.detectAsync(image: image, timestampInMilliseconds: timestamp)
        } catch {
            DebugLog.error("PoseLandmarker detectAsync error: \(error)", tag: "MediaPipe")
            notifyNoPose()
        }
    }

    private func notifyLandmarks(_ landmarks: [LandmarkPoint]) {
        detectionQueue.async { [weak self] in
            guard let self, self.isInitialized else { return }
            DispatchQueue.main.async {
                self.currentLandmarks = landmarks
                self.isTracking = true
            }
            self.onPoseDetected?(landmarks)
            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    private func notifyNoPose() {
        detectionQueue.async { [weak self] in
            guard let self, self.isInitialized else { return }
            DispatchQueue.main.async {
                self.currentLandmarks = []
                self.isTracking = false
            }
            self.onNoPoseDetected?()
            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    private static func modelPath() -> String? {
        if let path = Bundle.main.path(forResource: "pose_landmarker_lite", ofType: "task") {
            return path
        }
        if let url = Bundle.main.url(forResource: "pose_landmarker_lite", withExtension: "task", subdirectory: "Resources") {
            return url.path
        }
        return nil
    }
}

extension PoseLandmarkService: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if error != nil {
            notifyNoPose()
            return
        }

        guard let pose = result?.landmarks.first else {
            notifyNoPose()
            return
        }

        let landmarks = pose.map { LandmarkPoint(x: $0.x, y: $0.y, z: $0.z) }
        notifyLandmarks(landmarks)
    }
}
