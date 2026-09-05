import Foundation
import AVFoundation
import UIKit
import Combine
import MediaPipeTasksVision

/// MediaPipe GestureRecognizer for open/closed hand detection.
final class GestureRecognizerService: NSObject, ObservableObject {
    typealias GestureResultHandler = ([DetectedHandGesture]) -> Void
    typealias NoGestureHandler = () -> Void

    private var gestureRecognizer: GestureRecognizer?
    private var isInitialized = false
    private var lastUseGpu = false

    @Published private(set) var currentHands: [DetectedHandGesture] = []
    @Published private(set) var isTracking = false

    private let detectionQueue = DispatchQueue(label: "com.switch2go.mediapipe.gesture")
    /// Retain only the pixel buffer — never the CMSampleBuffer from AVCapture's pool.
    private var latestPixelBuffer: CVPixelBuffer?
    private var latestOrientation: UIImage.Orientation = .up
    private var pendingRequest = false
    private var isDetecting = false
    private var detectionStartTime: TimeInterval = 0
    private let detectionTimeout: TimeInterval = 0.4

    var onGesturesDetected: GestureResultHandler?
    var onNoGesturesDetected: NoGestureHandler?

    override init() {
        super.init()
    }

    func initialize(useGpu: Bool = false) -> Bool {
        if isInitialized && lastUseGpu == useGpu && gestureRecognizer != nil {
            pendingRequest = false
            isDetecting = false
            latestPixelBuffer = nil
            DebugLog.info("Reused existing GestureRecognizer (GPU: \(useGpu))", tag: "MediaPipe")
            return true
        }

        if gestureRecognizer != nil {
            close()
        }

        lastUseGpu = useGpu
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil

        do {
            guard let modelPath = Self.modelPath() else {
                DebugLog.error("Could not find gesture_recognizer.task model in bundle", tag: "MediaPipe")
                return false
            }

            let classifierOptions = ClassifierOptions()
            classifierOptions.scoreThreshold = 0.5

            let options = GestureRecognizerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numHands = 2
            options.baseOptions.delegate = useGpu ? .GPU : .CPU
            options.cannedGesturesClassifierOptions = classifierOptions
            options.gestureRecognizerLiveStreamDelegate = self

            gestureRecognizer = try GestureRecognizer(options: options)
            isInitialized = true
            DebugLog.info("GestureRecognizer initialized (GPU: \(useGpu))", tag: "MediaPipe")
            return true
        } catch {
            DebugLog.error("Failed to initialize GestureRecognizer: \(error)", tag: "MediaPipe")
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
            self?.currentHands = []
            self?.isTracking = false
        }
    }

    func reinitialize() {
        let useGpu = lastUseGpu
        detectionQueue.async { [weak self] in
            guard let self else { return }
            self.close()
            let success = self.initialize(useGpu: useGpu)
            DebugLog.log("GestureRecognizer reinitialize: \(success ? "success" : "FAILED")", tag: "MediaPipe", level: success ? .info : .error)
        }
    }

    func close() {
        gestureRecognizer = nil
        isInitialized = false
        pendingRequest = false
        isDetecting = false
        latestPixelBuffer = nil
        DispatchQueue.main.async { [weak self] in
            self?.currentHands = []
            self?.isTracking = false
        }
    }

    private func triggerDetectionIfNeeded() {
        if isDetecting && (CACurrentMediaTime() - detectionStartTime) > detectionTimeout {
            DebugLog.warn("Gesture detection timed out — resetting state", tag: "MediaPipe")
            isDetecting = false
        }

        guard pendingRequest, !isDetecting else { return }

        guard let pixelBuffer = latestPixelBuffer else {
            pendingRequest = false
            notifyNoGestures()
            return
        }

        guard isInitialized, let gestureRecognizer else {
            notifyNoGestures()
            return
        }

        guard let image = try? MPImage(pixelBuffer: pixelBuffer, orientation: latestOrientation) else {
            notifyNoGestures()
            return
        }

        isDetecting = true
        detectionStartTime = CACurrentMediaTime()
        let timestamp = Int(CACurrentMediaTime() * 1000)

        do {
            try gestureRecognizer.recognizeAsync(image: image, timestampInMilliseconds: timestamp)
        } catch {
            DebugLog.error("GestureRecognizer detectAsync error: \(error)", tag: "MediaPipe")
            notifyNoGestures()
        }
    }

    private func notifyHands(_ hands: [DetectedHandGesture]) {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.currentHands = hands
                self.isTracking = !hands.isEmpty
            }
            self.onGesturesDetected?(hands)
            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    private func notifyNoGestures() {
        detectionQueue.async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.currentHands = []
                self.isTracking = false
            }
            self.onNoGesturesDetected?()
            self.pendingRequest = false
            self.isDetecting = false
        }
    }

    private static func modelPath() -> String? {
        if let path = Bundle.main.path(forResource: "gesture_recognizer", ofType: "task") {
            return path
        }
        if let url = Bundle.main.url(forResource: "gesture_recognizer", withExtension: "task", subdirectory: "Resources") {
            return url.path
        }
        return nil
    }

    /// Front-camera frames are selfie-mirrored, so MediaPipe's "Left"/"Right"
    /// labels are opposite the user's hands. Flip to user-facing laterality.
    static func mapHandedness(_ label: String) -> HandSide {
        UserFacingLaterality.handSide(fromMediaPipeLabel: label, flip: true)
    }
}

extension GestureRecognizerService: GestureRecognizerLiveStreamDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: GestureRecognizer,
        didFinishGestureRecognition result: GestureRecognizerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        if error != nil {
            notifyNoGestures()
            return
        }

        guard let result else {
            notifyNoGestures()
            return
        }

        if result.landmarks.isEmpty {
            notifyNoGestures()
            return
        }

        var hands: [DetectedHandGesture] = []
        for index in 0..<result.landmarks.count {
            let sideLabel = result.handedness[safe: index]?.first?.categoryName ?? ""
            let side = Self.mapHandedness(sideLabel)
            let topGesture = result.gestures[safe: index]?.first
            hands.append(
                DetectedHandGesture(
                    side: side,
                    gestureName: topGesture?.categoryName ?? "None",
                    score: topGesture?.score ?? 0
                )
            )
        }

        notifyHands(hands)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
