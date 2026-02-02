import SwiftUI
import Combine
import VocableShared

/// Manages gaze tracking by coordinating camera, face detection, and gaze calculation.
class GazeTrackingManager: ObservableObject {
    // Camera and face detection
    private let cameraManager = CameraManager()
    private let faceLandmarkService = FaceLandmarkService()

    // Published state
    @Published var isTracking = false
    @Published var gazePosition: CGPoint = .zero
    @Published var rawGazeX: Float = 0
    @Published var rawGazeY: Float = 0
    @Published var isBlinking = false
    @Published var error: String?

    // Calibration
    private var calibration: GazeCalibration?
    private let storage: Storage
    private let logger: Logger

    // Subscriptions
    private var cancellables = Set<AnyCancellable>()

    init() {
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "GazeTracker")

        setupCalibration()
        setupBindings()
    }

    /// Initialize calibration with screen size.
    private func setupCalibration() {
        let screenSize = UIScreen.main.bounds.size

        calibration = GazeCalibration(
            screenWidth: Int32(screenSize.width),
            screenHeight: Int32(screenSize.height),
            calibrationMode: .polynomial,
            logger: { [weak self] message in
                self?.logger.debug(message: message)
            }
        )

        // Try to load existing calibration
        if let data = storage.loadCalibrationData(mode: "polynomial") {
            _ = calibration?.loadCalibrationData(data: data)
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
        faceLandmarkService.$isTracking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracking in
                self?.isTracking = tracking
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

    /// Start gaze tracking.
    func startTracking() {
        // Initialize face landmark detection
        guard faceLandmarkService.initialize(useGpu: true) else {
            error = "Failed to initialize face detection"
            return
        }

        // Start camera
        cameraManager.start()
        logger.info(message: "Gaze tracking started")
    }

    /// Stop gaze tracking.
    func stopTracking() {
        cameraManager.stop()
        faceLandmarkService.close()
        isTracking = false
        logger.info(message: "Gaze tracking stopped")
    }

    /// Get the calibration instance for calibration operations.
    func getCalibration() -> GazeCalibration? {
        return calibration
    }

    /// Reset calibration.
    func resetCalibration() {
        calibration?.resetCalibration()
        logger.info(message: "Calibration reset")
    }

    /// Convert raw gaze to screen coordinates.
    func gazeToScreen(gazeX: Float, gazeY: Float) -> CGPoint {
        if let screenPoint = calibration?.gazeToScreen(gazeX: gazeX, gazeY: gazeY) {
            return CGPoint(
                x: CGFloat(screenPoint.first?.intValue ?? 0),
                y: CGFloat(screenPoint.second?.intValue ?? 0)
            )
        }
        // Fallback: simple linear mapping
        let screenSize = UIScreen.main.bounds.size
        return CGPoint(
            x: CGFloat((gazeX + 1) / 2) * screenSize.width,
            y: CGFloat((gazeY + 1) / 2) * screenSize.height
        )
    }
}
