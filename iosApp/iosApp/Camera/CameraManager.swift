import AVFoundation
import UIKit
import Combine
/// Manages camera capture for eye tracking.
class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.switch2go.camera.session")

    /// Callback for each video frame
    var frameHandler: ((CMSampleBuffer) -> Void)?

    /// Called on the main thread whenever the device orientation changes.
    /// Consumers can use this to update screen dimensions, etc.
    var orientationDidChange: (() -> Void)?

    /// The current image orientation matching the device/camera configuration.
    /// Updated whenever the camera connection's rotation angle changes.
    private(set) var currentImageOrientation: UIImage.Orientation = .up

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

    private var orientationObserver: NSObjectProtocol?

    override init() {
        super.init()
        checkPermission()
        registerOrientationObserver()
    }

    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Orientation Handling

    /// Register for device orientation change notifications so we can update
    /// the camera connection's video rotation angle dynamically.
    private func registerOrientationObserver() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange()
        }
    }

    /// Called on the main thread when the device orientation changes.
    /// The camera stays locked to landscape-right (rotation 180°) — we never
    /// change videoRotationAngle dynamically because MediaPipe's liveStream
    /// mode doesn't handle frame dimension changes.  Instead, we just notify
    /// consumers so they can stop/start tracking based on orientation.
    private func handleOrientationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.orientationDidChange?()
        }
    }

    /// Check and request camera permission.
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
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

        // Configure connection for front camera with correct orientation
        if let connection = videoOutput.connection(with: .video) {
            // Mirror front camera so the image matches a natural "mirror" view.
            // This is important: the shared gaze calculator expects mirrored coordinates
            // (looking right → positive gazeX → right side of screen).
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }

            // Lock rotation to 180° (landscape right — home button RIGHT, camera LEFT).
            // Tracking is only supported in this orientation; we never change
            // the angle dynamically to avoid corrupting MediaPipe's internal state.
            //
            // Why 180°? The front camera sensor's native orientation is landscape-left.
            // When the device is in landscape-right (home button right), the sensor
            // image is 180° rotated from what the user sees. Rotation 180° corrects this.
            if connection.isVideoRotationAngleSupported(180) {
                connection.videoRotationAngle = 180
            }

            // After AVFoundation applies rotation (180°) and mirroring, the pixel
            // buffer contains an upright, horizontally-mirrored image — the same
            // as a "selfie" view.  Tell MediaPipe it's mirrored so landmarks match.
            currentImageOrientation = .upMirrored
        }

        captureSession.commitConfiguration()
    }

    /// Whether the device is currently in the tracking-supported orientation
    /// (landscape right — home button on RIGHT, camera on LEFT).
    ///
    /// UIInterfaceOrientation naming note:
    ///   .landscapeRight  → home button on the RIGHT  (what the user wants)
    ///   .landscapeLeft   → home button on the LEFT
    static var isTrackingSupportedOrientation: Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            return false
        }
        let orientation: UIInterfaceOrientation
        if #available(iOS 26.0, *) {
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }
        return orientation == .landscapeRight
    }

    /// Determine the correct video rotation angle for the current device orientation.
    /// Returns degrees to rotate the camera output so frames are upright for face detection.
    static func videoRotationAngleForCurrentOrientation() -> CGFloat {
        // Get the current interface orientation from the active window scene.
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            return 0  // Default: landscape (natural sensor orientation)
        }

        // Use effectiveGeometry on iOS 26+ if available, otherwise fall back
        let orientation: UIInterfaceOrientation
        if #available(iOS 26.0, *) {
            // effectiveGeometry.interfaceOrientation is the non-deprecated replacement
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }

        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return 0  // Landscape default
        }
    }

    /// Start camera capture.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }

            self.captureSession.startRunning()

            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stop camera capture.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }

            self.captureSession.stopRunning()

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
