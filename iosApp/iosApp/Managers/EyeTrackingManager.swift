import Foundation
import Combine
import AVFoundation
import VocableShared

/// Manages eye tracking using the VocableShared KMP framework
class EyeTrackingManager: ObservableObject {
    // MARK: - Published Properties

    @Published var gazePoint: GazePoint? = nil
    @Published var dwellProgress: Float = 0
    @Published var isTracking: Bool = false
    @Published var isCalibrated: Bool = false

    // MARK: - Private Properties

    private var gazeTracker: GazeTracker?
    private var gazeCalibration: GazeCalibration?
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?

    private var calibrationPoints: [(screenX: Float, screenY: Float, gazeX: Float, gazeY: Float)] = []
    private var isCalibrating: Bool = false

    // Dwell detection
    private var dwellStartTime: Date?
    private var lastGazePosition: GazePoint?
    private let dwellThreshold: Float = 0.05 // 5% of screen
    private let dwellDuration: TimeInterval = 1.0 // 1 second

    // MARK: - Initialization

    init() {
        setupGazeTracker()
    }

    // MARK: - Setup

    private func setupGazeTracker() {
        // Initialize the GazeTracker from VocableShared
        gazeTracker = GazeTracker(
            smoothingFactor: 0.3,
            useAdaptiveSmoothing: true
        )

        gazeCalibration = GazeCalibration(mode: .affine)

        // Load saved calibration if available
        loadCalibration()
    }

    // MARK: - Public Methods

    func startTracking() {
        guard !isTracking else { return }

        setupCameraCapture()
        isTracking = true

        print("Eye tracking started")
    }

    func stopTracking() {
        captureSession?.stopRunning()
        isTracking = false
        gazePoint = nil
        dwellProgress = 0

        print("Eye tracking stopped")
    }

    func startCalibration() {
        isCalibrating = true
        calibrationPoints.removeAll()
        gazeCalibration?.reset()

        print("Calibration started")
    }

    func recordCalibrationPoint(screenX: Float, screenY: Float) {
        guard isCalibrating, let currentGaze = gazePoint else {
            print("Cannot record calibration point - no gaze data")
            return
        }

        calibrationPoints.append((
            screenX: screenX,
            screenY: screenY,
            gazeX: currentGaze.x,
            gazeY: currentGaze.y
        ))

        print("Recorded calibration point \(calibrationPoints.count): screen(\(screenX), \(screenY)) -> gaze(\(currentGaze.x), \(currentGaze.y))")
    }

    func finishCalibration() {
        guard isCalibrating, calibrationPoints.count >= 4 else {
            print("Not enough calibration points")
            isCalibrating = false
            return
        }

        // Convert to format expected by VocableShared
        let screenPoints = calibrationPoints.map { point in
            LandmarkPoint(x: point.screenX, y: point.screenY)
        }
        let gazePoints = calibrationPoints.map { point in
            LandmarkPoint(x: point.gazeX, y: point.gazeY)
        }

        // Compute calibration using VocableShared
        gazeCalibration?.calibrate(
            screenPoints: screenPoints,
            gazePoints: gazePoints
        )

        isCalibrated = true
        isCalibrating = false

        // Save calibration
        saveCalibration()

        print("Calibration complete with \(calibrationPoints.count) points")
    }

    // MARK: - Camera Setup

    private func setupCameraCapture() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        // Get front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Front camera not available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

            if captureSession?.canAddOutput(videoOutput!) == true {
                captureSession?.addOutput(videoOutput!)
            }

            // Start capture on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }

        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    // MARK: - Gaze Processing

    private func processGazeResult(rawGazeX: Float, rawGazeY: Float) {
        // Apply calibration if available
        var calibratedX = rawGazeX
        var calibratedY = rawGazeY

        if isCalibrated, let calibration = gazeCalibration {
            let calibrated = calibration.apply(gazeX: rawGazeX, gazeY: rawGazeY)
            calibratedX = calibrated.x
            calibratedY = calibrated.y
        }

        // Apply smoothing using GazeTracker from VocableShared
        if let tracker = gazeTracker {
            let smoothed = tracker.smooth(gazeX: calibratedX, gazeY: calibratedY)
            calibratedX = smoothed.x
            calibratedY = smoothed.y
        }

        let newPoint = GazePoint(x: calibratedX, y: calibratedY)

        // Update dwell detection
        updateDwellDetection(newPoint: newPoint)

        // Publish on main thread
        DispatchQueue.main.async { [weak self] in
            self?.gazePoint = newPoint
        }
    }

    private func updateDwellDetection(newPoint: GazePoint) {
        if let lastPoint = lastGazePosition {
            let distance = sqrt(pow(newPoint.x - lastPoint.x, 2) + pow(newPoint.y - lastPoint.y, 2))

            if distance < dwellThreshold {
                // Still dwelling in same area
                if let startTime = dwellStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = Float(min(elapsed / dwellDuration, 1.0))

                    DispatchQueue.main.async { [weak self] in
                        self?.dwellProgress = progress
                    }

                    if progress >= 1.0 {
                        // Dwell complete - trigger selection
                        triggerDwellSelection(at: newPoint)
                        dwellStartTime = nil
                    }
                } else {
                    dwellStartTime = Date()
                }
            } else {
                // Moved - reset dwell
                dwellStartTime = nil
                DispatchQueue.main.async { [weak self] in
                    self?.dwellProgress = 0
                }
            }
        }

        lastGazePosition = newPoint
    }

    private func triggerDwellSelection(at point: GazePoint) {
        // Post notification for UI to handle selection
        NotificationCenter.default.post(
            name: .eyeTrackingDwellSelection,
            object: nil,
            userInfo: ["point": point]
        )

        // Reset dwell
        DispatchQueue.main.async { [weak self] in
            self?.dwellProgress = 0
        }
    }

    // MARK: - Persistence

    private func saveCalibration() {
        // Save calibration data to UserDefaults
        let data = calibrationPoints.map { ["sx": $0.screenX, "sy": $0.screenY, "gx": $0.gazeX, "gy": $0.gazeY] }
        UserDefaults.standard.set(data, forKey: "eyeTrackingCalibration")

        print("Calibration saved")
    }

    private func loadCalibration() {
        guard let data = UserDefaults.standard.array(forKey: "eyeTrackingCalibration") as? [[String: Float]],
              data.count >= 4 else {
            return
        }

        calibrationPoints = data.compactMap { dict in
            guard let sx = dict["sx"], let sy = dict["sy"],
                  let gx = dict["gx"], let gy = dict["gy"] else { return nil }
            return (screenX: sx, screenY: sy, gazeX: gx, gazeY: gy)
        }

        if calibrationPoints.count >= 4 {
            finishCalibration()
            print("Loaded saved calibration with \(calibrationPoints.count) points")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension EyeTrackingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process video frame for face/eye detection
        // This would integrate with iOS Vision framework or MediaPipe

        // For now, use placeholder gaze detection
        // In production, this would use FaceLandmarkDetector from VocableShared (iOS implementation)
        processVideoFrame(sampleBuffer)
    }

    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // TODO: Implement actual face landmark detection using Vision framework
        // and iris detection, then pass to IrisGazeCalculator from VocableShared

        // Placeholder: Generate simulated gaze data for testing
        // Remove this when real detection is implemented
        #if DEBUG
        // Simulated smooth movement for testing UI
        let time = Date().timeIntervalSince1970
        let x = Float(0.5 + 0.3 * sin(time))
        let y = Float(0.5 + 0.3 * cos(time * 0.7))
        processGazeResult(rawGazeX: x, rawGazeY: y)
        #endif
    }
}

// MARK: - Supporting Types

struct GazePoint {
    let x: Float
    let y: Float
}

// MARK: - Notifications

extension Notification.Name {
    static let eyeTrackingDwellSelection = Notification.Name("eyeTrackingDwellSelection")
}
