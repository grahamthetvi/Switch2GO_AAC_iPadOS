import AVFoundation
import UIKit
import Combine
/// Manages camera capture for eye tracking.
class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.switch2go.camera.session")

    /// Callback for each video frame
    var frameHandler: ((CMSampleBuffer) -> Void)?

    /// Called on the main thread whenever the device orientation changes.
    /// Consumers can use this to update screen dimensions, etc.
    var orientationDidChange: (() -> Void)?

    /// Capture session was interrupted (background, phone call, etc.).
    var onCaptureInterrupted: (() -> Void)?
    /// Interruption ended.
    var onCaptureResumed: (() -> Void)?
    /// Runtime error or media-services reset — session needs a full restart.
    var onCaptureRuntimeError: (() -> Void)?

    /// The current image orientation metadata for MediaPipe.
    /// This tells MPImage how pixel rows/columns relate to an upright image given
    /// the connection rotation + mirroring. It is NOT the device orientation.
    private(set) var mediaPipeSampleBufferOrientation: UIImage.Orientation = .up

    /// The current video rotation angle applied to the camera connection.
    @Published private(set) var currentVideoRotationAngle: CGFloat = 0

    @Published var isRunning = false
    @Published var permissionGranted = false
    @Published var error: CameraError?

    enum CameraError: Error, LocalizedError {
        case noFrontCamera
        case permissionDenied
        case setupFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noFrontCamera:
                return "No front camera available on this device"
            case .permissionDenied:
                return "Camera permission was denied"
            case .setupFailed(let error):
                return "Camera setup failed: \(error.localizedDescription)"
            }
        }
    }

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var debugRotationObserver: NSObjectProtocol?

    override init() {
        super.init()
        // Sync already-decided authorization only. Do not prompt here —
        // GazeTrackingManager is created at launch, and requesting camera
        // access in init interrupts first-launch onboarding with a system alert.
        syncExistingAuthorization()

        debugRotationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugCameraRotationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRotationAngle()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: AVCaptureSession.interruptionEndedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mediaServicesWereReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    deinit {
        rotationObservation?.invalidate()
        if let token = debugRotationObserver {
            NotificationCenter.default.removeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onCaptureInterrupted?()
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onCaptureResumed?()
        }
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onCaptureRuntimeError?()
        }
    }

    @objc private func mediaServicesWereReset(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onCaptureRuntimeError?()
        }
    }

    // MARK: - Orientation Handling

    /// Handle changes to the rotation angle from the rotation coordinator.
    private func handleRotationAngleChange(_ angle: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let debugRotation = AppSettings.shared.debugCameraRotation
            let targetAngle = debugRotation >= 0 ? CGFloat(debugRotation) : angle
            
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(targetAngle) {
                    self.captureSession.beginConfiguration()
                    connection.videoRotationAngle = targetAngle
                    self.captureSession.commitConfiguration()
                }
            }
            
            DispatchQueue.main.async {
                self.currentVideoRotationAngle = targetAngle
                self.orientationDidChange?()
            }
        }
    }
    
    /// Update the camera rotation angle manually (used for debugging)
    func updateRotationAngle() {
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture {
            handleRotationAngleChange(angle)
        }
    }

    /// Apply current authorization without prompting. Used at init so cold
    /// launch does not show the system camera dialog until tracking starts.
    private func syncExistingAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()

        case .denied, .restricted:
            permissionGranted = false
            error = .permissionDenied

        case .notDetermined:
            break

        @unknown default:
            permissionGranted = false
        }
    }

    /// Check and request camera permission when tracking actually starts.
    private func checkPermission(onGranted: (() -> Void)? = nil) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            onGranted?()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        onGranted?()
                    } else {
                        self?.error = .permissionDenied
                    }
                }
            }

        case .denied, .restricted:
            permissionGranted = false
            error = .permissionDenied

        @unknown default:
            permissionGranted = false
        }
    }

    /// Setup camera capture session.
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium  // 480p — lower noise, faster processing

        // Get front camera
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            DispatchQueue.main.async {
                self.error = .noFrontCamera
            }
            captureSession.commitConfiguration()
            return
        }

        do {
            // Configure camera for optimal face tracking
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()

            // Add input
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .setupFailed(error)
            }
            captureSession.commitConfiguration()
            return
        }

        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Set up rotation coordinator for iOS 17+
        let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
        self.rotationCoordinator = coordinator
        self.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
            self?.handleRotationAngleChange(coordinator.videoRotationAngleForHorizonLevelCapture)
        }

        // Configure connection for front camera with correct orientation
        if let connection = videoOutput.connection(with: .video) {
            // Mirror front camera so the image matches a natural "mirror" view.
            // This is important: the shared gaze calculator expects mirrored coordinates
            // (looking right → positive gazeX → right side of screen).
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }

            // Lock rotation based on device type and current orientation
            let debugRotation = AppSettings.shared.debugCameraRotation
            let targetAngle = debugRotation >= 0 ? CGFloat(debugRotation) : coordinator.videoRotationAngleForHorizonLevelCapture
            
            if connection.isVideoRotationAngleSupported(targetAngle) {
                connection.videoRotationAngle = targetAngle
            }

            DispatchQueue.main.async { [weak self] in
                self?.currentVideoRotationAngle = targetAngle
            }

            // After AVFoundation applies rotation and mirroring, the pixel
            // buffer contains an upright, horizontally-mirrored image — the same
            // as a "selfie" view.  Tell MediaPipe it's mirrored so landmarks match.
            mediaPipeSampleBufferOrientation = .upMirrored
        }

        captureSession.commitConfiguration()
    }

    /// Whether tracking is allowed in the current interface orientation.
    /// Supported: portrait and both landscapes. Unsupported: portrait upside-down
    /// (front camera at the bottom). Touch and switch still work in that orientation.
    ///
    /// UIInterfaceOrientation naming note:
    ///   .landscapeRight  → home button / USB-C on the RIGHT, camera on the LEFT
    ///   .landscapeLeft   → home button / USB-C on the LEFT, camera on the RIGHT
    ///   .portraitUpsideDown → front camera at the bottom (tracking off)
    static var isTrackingSupportedOrientation: Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            return false
        }

        let orientation: UIInterfaceOrientation
        if #available(iOS 18.0, *) {
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }

        return orientation != .portraitUpsideDown
    }

    /// Start camera capture. Requests permission on first use if still undetermined.
    func start() {
        checkPermission { [weak self] in
            self?.startSessionIfNeeded()
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.inputs.isEmpty {
                self.configureSession()
            }

            guard !self.captureSession.inputs.isEmpty else { return }
            guard !self.captureSession.isRunning else {
                DispatchQueue.main.async { self.isRunning = true }
                return
            }

            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stop camera capture.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameHandler?(sampleBuffer)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame was dropped - this is normal under heavy load
    }
}
