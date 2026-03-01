import SwiftUI
import Combine
import VocableShared
 
/// Manages the calibration process, collecting gaze samples and computing the calibration transform.
class CalibrationManager: ObservableObject {
    @Published var calibrationPoints: [CGPoint] = []
    @Published var collectionProgress: Double = 0
    @Published var calibrationError: Double = 0
    
    /// Computed accuracy property (0.0 to 1.0) based on calibration error.
    /// Lower error = higher accuracy. Error is in pixels, so we convert to a percentage.
    var accuracy: Double {
        // Convert error to accuracy: lower error = higher accuracy
        // Assuming max reasonable error is ~50 pixels, map to 0-1 range
        let maxError: Double = 50.0
        let normalizedError = min(calibrationError / maxError, 1.0)
        return max(0.0, 1.0 - normalizedError)
    }
 
    private var gazeCalibration: GazeCalibration?
    private let storage: Storage
    private let logger: Logger
 
    // Collection parameters
    private let samplesPerPoint = 30
    private let sampleInterval: TimeInterval = 0.05 // 20 samples per second
    private var currentPointIndex = 0
    private var isCollectingSamples = false
 
    init() {
        storage = StorageKt.createStorage()
        logger = LoggerKt.createLogger(tag: "Calibration")
    }
 
    /// Generate the 9-point calibration grid.
    func generateCalibrationPoints(screenWidth: CGFloat, screenHeight: CGFloat) {
        // Initialize the GazeCalibration from shared module
        gazeCalibration = GazeCalibration(
            screenWidth: Int32(screenWidth),
            screenHeight: Int32(screenHeight),
            calibrationMode: .polynomial,
            logger: { [weak self] message in
                self?.logger.debug(message: message)
            }
        )
 
        // Generate calibration points in shared module
        if let points = gazeCalibration?.generateCalibrationPoints(marginPercent: 0.1) {
            calibrationPoints = points.map { point in
                CGPoint(
                    x: CGFloat(point.first?.intValue ?? 0),
                    y: CGFloat(point.second?.intValue ?? 0)
                )
            }
        }
 
        currentPointIndex = 0
        logger.info(message: "Generated \(calibrationPoints.count) calibration points")
    }
 
    /// Get the current calibration point index.
    func getCurrentPointIndex() -> Int {
        return currentPointIndex
    }
 
    /// Add a gaze sample for the current calibration point.
    func addSample(gazeX: Float, gazeY: Float) -> Int {
        guard let calibration = gazeCalibration else { return 0 }
        return Int(calibration.addCalibrationSample(
            pointIndex: Int32(currentPointIndex),
            gazeX: gazeX,
            gazeY: gazeY
        ))
    }
 
    /// Collect gaze samples for the current calibration point.
    func collectSamples(gazeX: Float, gazeY: Float, completion: @escaping (Bool) -> Void) {
        guard gazeCalibration != nil else {
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

            // Add sample to calibration
            _ = self.addSample(gazeX: gazeX, gazeY: gazeY)
            samplesCollected += 1

            DispatchQueue.main.async {
                self.collectionProgress = Double(samplesCollected) / Double(self.samplesPerPoint)
            }

            if samplesCollected >= self.samplesPerPoint {
                timer.invalidate()
                self.logger.info(message: "Collected \(samplesCollected) samples for point \(self.currentPointIndex)")
                completion(true)
            }
        }
    }
    
    /// Collect gaze samples from a GazeTrackingManager for the current calibration point.
    func collectSamples(from gazeManager: GazeTrackingManager, completion: @escaping (Bool) -> Void) {
        guard gazeCalibration != nil, !isCollectingSamples else {
            completion(false)
            return
        }

        isCollectingSamples = true
        var samplesCollected = 0
        collectionProgress = 0

        // Create a timer to collect samples
        // Timer runs on main run loop, so we can access @Published properties directly
        let timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Get current gaze values from the manager
            let gazeX = gazeManager.rawGazeX
            let gazeY = gazeManager.rawGazeY

            // Add sample to calibration
            _ = self.addSample(gazeX: gazeX, gazeY: gazeY)
            samplesCollected += 1

            self.collectionProgress = Double(samplesCollected) / Double(self.samplesPerPoint)

            if samplesCollected >= self.samplesPerPoint {
                timer.invalidate()
                self.isCollectingSamples = false
                self.logger.info(message: "Collected \(samplesCollected) samples for point \(self.currentPointIndex)")
                completion(true)
            }
        }
        
        // Ensure timer is added to main run loop
        RunLoop.main.add(timer, forMode: .common)
    }
 
    /// Advance to the next calibration point.
    func advanceToNextPoint() -> Bool {
        if currentPointIndex < calibrationPoints.count - 1 {
            currentPointIndex += 1
            collectionProgress = 0
            return true
        }
        return false
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
                    self?.calibrationError = Double(error)
 
                    // Save calibration data
                    if let data = calibration.getCalibrationData() {
                        _ = self?.storage.saveCalibrationData(data: data, mode: "polynomial")
                        self?.logger.info(message: "Calibration saved with error: \(error) pixels")
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

        // Get screen size from window scene or use stored size
        var screenSizeToUse = CGSize(width: 1024, height: 1366) // Default iPad Pro size
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let screen = windowScene.windows.first?.screen {
            screenSizeToUse = screen.bounds.size
        }

        // Create new calibration and load data
        gazeCalibration = GazeCalibration(
            screenWidth: Int32(screenSizeToUse.width),
            screenHeight: Int32(screenSizeToUse.height),
            calibrationMode: .polynomial,
            logger: { [weak self] message in
                self?.logger.debug(message: message)
            }
        )
 
        let loaded = gazeCalibration?.loadCalibrationData(data: data) ?? false
        if loaded {
            calibrationError = Double(data.calibrationError)
            logger.info(message: "Loaded existing calibration with error: \(calibrationError) pixels")
        }
 
        return loaded
    }
 
    /// Check if calibration has enough samples.
    func hasEnoughSamples() -> Bool {
        return gazeCalibration?.hasEnoughSamples() ?? false
    }
 
    /// Reset calibration state.
    func reset() {
        gazeCalibration?.resetCalibration()
        currentPointIndex = 0
        collectionProgress = 0
        calibrationError = 0
        calibrationPoints = []
    }
}
 
