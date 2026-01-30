import AVFoundation
import UIKit

/// Manages camera capture for eye tracking.
class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.switch2go.camera.session")

    /// Callback for each video frame
    var frameHandler: ((CMSampleBuffer) -> Void)?

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

    override init() {
        super.init()
        checkPermission()
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
        captureSession.sessionPreset = .high

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

        // Configure connection
        if let connection = videoOutput.connection(with: .video) {
            // Set to portrait orientation
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            // Mirror front camera
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()
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
