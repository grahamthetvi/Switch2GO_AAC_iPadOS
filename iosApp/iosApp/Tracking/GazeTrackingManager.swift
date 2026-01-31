import SwiftUI
import Combine
import VocableShared

/// Manages gaze tracking by coordinating camera, face detection, and gaze calculation.
class GazeTrackingManager: ObservableObject {
    // Camera and face detection
    private let cameraManager = CameraManager()
    private let faceLandmarkService = FaceLandmarkService()

    // Shared module gaze tracker
    private var gazeTracker: GazeTracker?

    // Published state
    @Published var isTracking = false
    @Published var gazePosition: CGPoint = .zero
    @Published var rawGazeX: Float = 0
    @Published var rawGazeY: Float = 0
    @Published var isBlinking = false
    @Published var error: String?

    // Subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupGazeTracker()
        setupBindings()
    }

    /// Initialize the shared module gaze tracker.
    private func setupGazeTracker() {
        let screenSize = UIScreen.main.bounds.size

        // Create platform implementations from shared module
        let storage = StorageKt.createStorage()
        let logger = LoggerKt.createLogger(tag: "GazeTracker")

        // Create the gaze tracker
        gazeTracker = GazeTracker(
            screenWidth: Int32(screenSize.width),
            screenHeight: Int32(screenSize.height),
            storage: storage,
            logger: logger
        )

        // Configure tracker settings
        gazeTracker?.smoothingMode = SmoothingMode.adaptiveKalman
        gazeTracker?.eyeSelection = EyeSelection.bothEyes

        // Try to load existing calibration
        if let data = storage.loadCalibrationData(mode: "polynomial") {
            gazeTracker?.loadCalibration(data: data)
            logger.info(message: "Loaded existing calibration")
        }
    }

    /// Setup bindings between camera, face detection, and gaze tracking.
    private func setupBindings() {
        // Handle camera frames -> send to face detection
        cameraManager.frameHandler = { [weak self] sampleBuffer in
            self?.faceLandmarkService.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: .up
            )
        }

        // Handle face detection results -> process gaze
        faceLandmarkService.$currentLandmarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] landmarks in
                if let landmarks = landmarks {
                    self?.processLandmarks(landmarks)
                } else {
                    self?.isTracking = false
                }
            }
            .store(in: &cancellables)

        // Handle camera errors
        cameraManager.$error
            .compactMap { $0?.localizedDescription }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                self?.error = errorMessage
            }
            .store(in: &cancellables)
    }

    /// Process detected face landmarks to calculate gaze.
    private func processLandmarks(_ mpLandmarks: [Any]) {
        guard let tracker = gazeTracker else { return }

        // Convert MediaPipe landmarks to shared module format
        // MediaPipe returns NormalizedLandmark objects
        var landmarkPoints: [LandmarkPoint] = []

        for landmark in mpLandmarks {
            // Access landmark properties via reflection or casting
            // This depends on how MediaPipe Swift SDK exposes landmarks
            if let normalizedLandmark = landmark as? NormalizedLandmark {
                let point = LandmarkPoint(
                    x: normalizedLandmark.x,
                    y: normalizedLandmark.y,
                    z: normalizedLandmark.z ?? 0
                )
                landmarkPoints.append(point)
            }
        }

        guard !landmarkPoints.isEmpty else {
            isTracking = false
            return
        }

        // Process through shared gaze tracker
        if let result = tracker.processLandmarks(landmarks: landmarkPoints) {
            // Store raw gaze values (for calibration)
            rawGazeX = result.gazeX
            rawGazeY = result.gazeY

            // Get calibrated screen position
            if let screenPoint = tracker.gazeToScreen(gazeResult: result) {
                gazePosition = CGPoint(
                    x: CGFloat(screenPoint.first),
                    y: CGFloat(screenPoint.second)
                )
            }

            // Update blink state
            isBlinking = result.leftBlink && result.rightBlink

            isTracking = true
        }
    }

    /// Start gaze tracking.
    func startTracking() {
        // Initialize face landmark detection
        guard faceLandmarkService.initialize(useGpu: true) else {
            error = "Failed to initialize face detection"
            return
        }

        // Start camera
        cameraManager.start()
    }

    /// Stop gaze tracking.
    func stopTracking() {
        cameraManager.stop()
        faceLandmarkService.close()
        isTracking = false
    }

    /// Reset calibration.
    func resetCalibration() {
        gazeTracker?.resetCalibration()
    }
}

// MARK: - NormalizedLandmark Protocol
// This protocol matches MediaPipe's NormalizedLandmark structure
protocol NormalizedLandmark {
    var x: Float { get }
    var y: Float { get }
    var z: Float? { get }
    var visibility: Float? { get }
    var presence: Float? { get }
}
