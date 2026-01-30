import SwiftUI
import VocableShared

/// Manages the calibration process, collecting gaze samples and computing the calibration transform.
class CalibrationManager: ObservableObject {
    @Published var calibrationPoints: [CGPoint] = []
    @Published var collectionProgress: Double = 0
    @Published var accuracy: Double = 0

    private var gazeCalibration: GazeCalibration?
    private let storage: Storage_
    private let logger: Logger_

    // Collection parameters
    private let samplesPerPoint = 30
    private let sampleInterval: TimeInterval = 0.05 // 20 samples per second

    init() {
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "Calibration")
    }

    /// Generate the 9-point calibration grid.
    func generateCalibrationPoints(screenWidth: CGFloat, screenHeight: CGFloat) {
        let margin: CGFloat = 60
        let width = screenWidth - (margin * 2)
        let height = screenHeight - (margin * 2)

        // 9-point grid: 3x3
        calibrationPoints = [
            CGPoint(x: margin, y: margin),                           // Top-left
            CGPoint(x: margin + width / 2, y: margin),              // Top-center
            CGPoint(x: margin + width, y: margin),                  // Top-right
            CGPoint(x: margin, y: margin + height / 2),             // Middle-left
            CGPoint(x: margin + width / 2, y: margin + height / 2), // Center
            CGPoint(x: margin + width, y: margin + height / 2),     // Middle-right
            CGPoint(x: margin, y: margin + height),                 // Bottom-left
            CGPoint(x: margin + width / 2, y: margin + height),     // Bottom-center
            CGPoint(x: margin + width, y: margin + height)          // Bottom-right
        ]

        // Initialize the GazeCalibration from shared module
        gazeCalibration = GazeCalibration(
            screenWidth: Int32(screenWidth),
            screenHeight: Int32(screenHeight),
            logger: { message in
                self.logger.debug(message: message)
            }
        )

        // Generate calibration points in shared module
        gazeCalibration?.generateCalibrationPoints()

        logger.info(message: "Generated \(calibrationPoints.count) calibration points")
    }

    /// Collect gaze samples for the current calibration point.
    func collectSamples(from gazeManager: GazeTrackingManager, completion: @escaping (Bool) -> Void) {
        guard let calibration = gazeCalibration else {
            completion(false)
            return
        }

        var samplesCollected = 0
        collectionProgress = 0

        // Create a timer to collect samples
        Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // Get current gaze position from the tracker
            if gazeManager.isTracking {
                let gazeX = Float(gazeManager.rawGazeX)
                let gazeY = Float(gazeManager.rawGazeY)

                // Add sample to calibration
                calibration.addSample(gazeX: gazeX, gazeY: gazeY)
                samplesCollected += 1

                DispatchQueue.main.async {
                    self.collectionProgress = Double(samplesCollected) / Double(self.samplesPerPoint)
                }

                if samplesCollected >= self.samplesPerPoint {
                    timer.invalidate()
                    calibration.advanceToNextPoint()
                    self.logger.info(message: "Collected \(samplesCollected) samples for point")
                    completion(true)
                }
            }
        }
    }

    /// Compute the calibration transform after all points are collected.
    func computeCalibration(completion: @escaping (Bool) -> Void) {
        guard let calibration = gazeCalibration else {
            completion(false)
            return
        }

        // Compute calibration on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = calibration.computeCalibration()

            DispatchQueue.main.async {
                if success {
                    // Get calibration error (lower is better)
                    let error = calibration.getCalibrationError()
                    self?.accuracy = max(0, 1.0 - Double(error))

                    // Save calibration data
                    if let data = calibration.getCalibrationData() {
                        self?.storage.saveCalibrationData(data: data, mode: "polynomial")
                        self?.logger.info(message: "Calibration saved with accuracy: \(self?.accuracy ?? 0)")
                    }
                }

                completion(success)
            }
        }
    }

    /// Load existing calibration if available.
    func loadExistingCalibration() -> Bool {
        guard let data = storage.loadCalibrationData(mode: "polynomial") else {
            return false
        }

        // Create new calibration and load data
        gazeCalibration = GazeCalibration(
            screenWidth: data.screenWidth,
            screenHeight: data.screenHeight,
            logger: { [weak self] message in
                self?.logger.debug(message: message)
            }
        )

        gazeCalibration?.loadCalibrationData(data: data)
        accuracy = max(0, 1.0 - Double(data.calibrationError))

        logger.info(message: "Loaded existing calibration with accuracy: \(accuracy)")
        return true
    }
}
