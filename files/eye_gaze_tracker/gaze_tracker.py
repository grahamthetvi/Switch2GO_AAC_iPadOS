"""
Eye Gaze Tracker using MediaPipe Iris and Kalman Filters
Based on: "MediaPipe Iris and Kalman Filter for Robust Eye Gaze Tracking"
by Ramesh V et al. (2025)

This implementation combines MediaPipe's real-time iris tracking with
Kalman Filters for noise reduction and predictive smoothing.
"""

import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from dataclasses import dataclass
from typing import Tuple, Optional, List
import time
import urllib.request
import os


@dataclass
class GazeData:
    """Container for gaze estimation results."""
    left_gaze: Optional[np.ndarray] = None
    right_gaze: Optional[np.ndarray] = None
    combined_gaze: Optional[np.ndarray] = None
    screen_point: Optional[Tuple[int, int]] = None
    left_iris_center: Optional[Tuple[float, float]] = None
    right_iris_center: Optional[Tuple[float, float]] = None
    confidence: float = 0.0


class KalmanFilter2D:
    """
    2D Kalman Filter for gaze smoothing.
    
    Implements a constant velocity model to predict and smooth
    gaze positions, reducing noise and handling rapid movements.
    """
    
    def __init__(self, process_noise: float = 1e-4, measurement_noise: float = 1e-2):
        """
        Initialize the Kalman Filter.
        
        Args:
            process_noise: Process noise covariance (lower = smoother, more lag)
            measurement_noise: Measurement noise covariance (higher = trust predictions more)
        """
        # State: [x, y, vx, vy] (position and velocity)
        self.state = np.zeros(4)
        
        # State transition matrix (constant velocity model)
        self.F = np.array([
            [1, 0, 1, 0],
            [0, 1, 0, 1],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ], dtype=np.float32)
        
        # Measurement matrix (we only observe position)
        self.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0]
        ], dtype=np.float32)
        
        # Base noise parameters
        self.base_process_noise = process_noise
        self.base_measurement_noise = measurement_noise
        
        # Process noise covariance
        self.Q = np.eye(4) * process_noise
        
        # Measurement noise covariance
        self.R = np.eye(2) * measurement_noise
        
        # State covariance matrix
        self.P = np.eye(4)
        
        self.initialized = False
    
    def predict(self) -> np.ndarray:
        """Predict the next state."""
        if not self.initialized:
            return self.state[:2]
        
        # Predict state
        self.state = self.F @ self.state
        
        # Predict covariance
        self.P = self.F @ self.P @ self.F.T + self.Q
        
        return self.state[:2]
    
    def update(self, measurement: np.ndarray) -> np.ndarray:
        """
        Update the filter with a new measurement.
        
        Args:
            measurement: [x, y] position measurement
            
        Returns:
            Filtered [x, y] position
        """
        measurement = np.array(measurement, dtype=np.float32)
        
        if not self.initialized:
            self.state[:2] = measurement
            self.initialized = True
            return measurement
        
        # Predict step
        self.predict()
        
        # Kalman gain
        S = self.H @ self.P @ self.H.T + self.R
        K = self.P @ self.H.T @ np.linalg.inv(S)
        
        # Update state
        innovation = measurement - self.H @ self.state
        self.state = self.state + K @ innovation
        
        # Update covariance
        I = np.eye(4)
        self.P = (I - K @ self.H) @ self.P
        
        return self.state[:2]
    
    def reset(self):
        """Reset the filter state."""
        self.state = np.zeros(4)
        self.P = np.eye(4)
        self.initialized = False
    
    def get_velocity(self) -> float:
        """Get current velocity magnitude."""
        return np.sqrt(self.state[2]**2 + self.state[3]**2)


class AdaptiveKalmanFilter2D:
    """
    Adaptive 2D Kalman Filter with velocity-dependent noise parameters.
    
    Dynamically adjusts measurement and process noise based on velocity:
    - High velocity (saccades): Lower measurement noise, trust measurements
    - Low velocity (fixation): Higher measurement noise, trust predictions (smooth)
    
    This is particularly effective for eye gaze tracking where:
    - Saccades need to be tracked accurately and quickly
    - Fixations need to be smooth and stable for dwelling
    """
    
    def __init__(
        self,
        base_process_noise: float = 1e-4,
        base_measurement_noise: float = 1e-2,
        low_velocity_threshold: float = 0.02,
        high_velocity_threshold: float = 0.15,
        dwell_measurement_multiplier: float = 3.0,
        rapid_measurement_multiplier: float = 0.3
    ):
        """
        Initialize the Adaptive Kalman Filter.
        
        Args:
            base_process_noise: Base process noise covariance
            base_measurement_noise: Base measurement noise covariance
            low_velocity_threshold: Velocity below which we consider "dwelling"
            high_velocity_threshold: Velocity above which we consider "rapid movement"
            dwell_measurement_multiplier: Multiplier for measurement noise during dwell (higher = smoother)
            rapid_measurement_multiplier: Multiplier for measurement noise during rapid movement (lower = responsive)
        """
        self.state = np.zeros(4)  # [x, y, vx, vy]
        
        self.F = np.array([
            [1, 0, 1, 0],
            [0, 1, 0, 1],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ], dtype=np.float32)
        
        self.H = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0]
        ], dtype=np.float32)
        
        self.base_process_noise = base_process_noise
        self.base_measurement_noise = base_measurement_noise
        self.low_velocity_threshold = low_velocity_threshold
        self.high_velocity_threshold = high_velocity_threshold
        self.dwell_measurement_multiplier = dwell_measurement_multiplier
        self.rapid_measurement_multiplier = rapid_measurement_multiplier
        
        self.Q = np.eye(4) * base_process_noise
        self.R = np.eye(2) * base_measurement_noise
        self.P = np.eye(4)
        
        self.initialized = False
        self.velocity_history = []
        self.velocity_history_size = 5
        
        # Current adaptive values (for monitoring)
        self.current_measurement_noise = base_measurement_noise
        self.current_process_noise = base_process_noise
    
    def _get_smoothed_velocity(self) -> float:
        """Get smoothed velocity from history."""
        if not self.velocity_history:
            return self._get_velocity()
        return np.mean(self.velocity_history)
    
    def _get_velocity(self) -> float:
        """Get current velocity magnitude."""
        return np.sqrt(self.state[2]**2 + self.state[3]**2)
    
    def _update_velocity_history(self):
        """Update velocity history."""
        self.velocity_history.append(self._get_velocity())
        if len(self.velocity_history) > self.velocity_history_size:
            self.velocity_history.pop(0)
    
    def _get_adaptive_measurement_noise(self) -> np.ndarray:
        """Get adaptive measurement noise based on velocity."""
        velocity = self._get_smoothed_velocity()
        
        if velocity <= self.low_velocity_threshold:
            # Dwelling - high noise for smoothness
            multiplier = self.dwell_measurement_multiplier
        elif velocity >= self.high_velocity_threshold:
            # Rapid movement - low noise for responsiveness
            multiplier = self.rapid_measurement_multiplier
        else:
            # Interpolate using smoothstep
            t = (velocity - self.low_velocity_threshold) / \
                (self.high_velocity_threshold - self.low_velocity_threshold)
            smooth_t = t * t * (3 - 2 * t)  # smoothstep
            multiplier = self.dwell_measurement_multiplier + \
                        smooth_t * (self.rapid_measurement_multiplier - self.dwell_measurement_multiplier)
        
        self.current_measurement_noise = self.base_measurement_noise * multiplier
        return np.eye(2) * self.current_measurement_noise
    
    def _get_adaptive_process_noise(self) -> np.ndarray:
        """Get adaptive process noise based on velocity."""
        velocity = self._get_smoothed_velocity()
        velocity_factor = np.clip(velocity / self.high_velocity_threshold, 0.5, 2.0)
        self.current_process_noise = self.base_process_noise * velocity_factor
        return np.eye(4) * self.current_process_noise
    
    def predict(self) -> np.ndarray:
        """Predict the next state."""
        if not self.initialized:
            return self.state[:2]
        
        self.Q = self._get_adaptive_process_noise()
        self.state = self.F @ self.state
        self.P = self.F @ self.P @ self.F.T + self.Q
        
        return self.state[:2]
    
    def update(self, measurement: np.ndarray) -> np.ndarray:
        """Update the filter with a new measurement."""
        measurement = np.array(measurement, dtype=np.float32)
        
        if not self.initialized:
            self.state[:2] = measurement
            self.initialized = True
            return measurement
        
        # Predict
        self.predict()
        
        # Get adaptive measurement noise
        self.R = self._get_adaptive_measurement_noise()
        
        # Kalman gain
        S = self.H @ self.P @ self.H.T + self.R
        K = self.P @ self.H.T @ np.linalg.inv(S)
        
        # Update state
        innovation = measurement - self.H @ self.state
        self.state = self.state + K @ innovation
        
        # Update covariance
        I = np.eye(4)
        self.P = (I - K @ self.H) @ self.P
        
        # Update velocity history
        self._update_velocity_history()
        
        return self.state[:2]
    
    def reset(self):
        """Reset the filter state."""
        self.state = np.zeros(4)
        self.P = np.eye(4)
        self.initialized = False
        self.velocity_history = []
        self.current_measurement_noise = self.base_measurement_noise
        self.current_process_noise = self.base_process_noise
    
    def is_dwelling(self) -> bool:
        """Check if currently in dwelling mode."""
        return self._get_smoothed_velocity() <= self.low_velocity_threshold
    
    def get_velocity(self) -> float:
        """Get current velocity magnitude."""
        return self._get_velocity()


class EyeGazeTracker:
    """
    Real-time eye gaze tracker using MediaPipe Iris and Kalman Filters.
    
    Features:
    - Real-time iris detection and tracking
    - Kalman filter smoothing for stable gaze estimation
    - Screen coordinate mapping with calibration
    - Depth estimation from iris size
    """
    
    # MediaPipe Face Mesh landmark indices for eyes
    # Left eye landmarks
    LEFT_EYE_OUTER = 33
    LEFT_EYE_INNER = 133
    LEFT_IRIS_CENTER = 468  # Iris center landmark
    LEFT_IRIS_LANDMARKS = [468, 469, 470, 471, 472]
    
    # Right eye landmarks  
    RIGHT_EYE_OUTER = 362
    RIGHT_EYE_INNER = 263
    RIGHT_IRIS_CENTER = 473  # Iris center landmark
    RIGHT_IRIS_LANDMARKS = [473, 474, 475, 476, 477]
    
    # Eye contour landmarks for blink detection
    LEFT_EYE_TOP = 159
    LEFT_EYE_BOTTOM = 145
    RIGHT_EYE_TOP = 386
    RIGHT_EYE_BOTTOM = 374
    
    # Model URL and path
    MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
    MODEL_PATH = "face_landmarker.task"
    
    def __init__(
        self,
        camera_id: int = 0,
        screen_width: int = 1920,
        screen_height: int = 1080,
        process_noise: float = 1e-4,
        measurement_noise: float = 1e-2,
        smoothing_factor: float = 0.3,
        sensitivity_x: float = 2.5,
        sensitivity_y: float = 3.0,
        offset_x: float = 0.0,
        offset_y: float = 0.3
    ):
        """
        Initialize the eye gaze tracker.
        
        Args:
            camera_id: Camera device ID
            screen_width: Screen width in pixels for coordinate mapping
            screen_height: Screen height in pixels for coordinate mapping
            process_noise: Kalman filter process noise
            measurement_noise: Kalman filter measurement noise
            smoothing_factor: Additional exponential smoothing factor (0-1)
            sensitivity_x: Horizontal gaze sensitivity multiplier (default 2.5)
            sensitivity_y: Vertical gaze sensitivity multiplier (default 3.0)
            offset_x: Horizontal gaze offset (-1 to 1, positive = shift right)
            offset_y: Vertical gaze offset (-1 to 1, positive = shift down)
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.smoothing_factor = smoothing_factor
        self.sensitivity_x = sensitivity_x
        self.sensitivity_y = sensitivity_y
        self.offset_x = offset_x
        self.offset_y = offset_y
        
        # Download model if needed
        self._ensure_model_exists()
        
        # Initialize MediaPipe Face Landmarker (new Tasks API)
        base_options = python.BaseOptions(model_asset_path=self.MODEL_PATH)
        options = vision.FaceLandmarkerOptions(
            base_options=base_options,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
            min_tracking_confidence=0.5
        )
        self.face_landmarker = vision.FaceLandmarker.create_from_options(options)
        
        # Initialize Kalman filters for each eye
        self.left_kalman = KalmanFilter2D(process_noise, measurement_noise)
        self.right_kalman = KalmanFilter2D(process_noise, measurement_noise)
        self.combined_kalman = KalmanFilter2D(process_noise, measurement_noise)
        
        # Calibration data
        self.calibration_points: List[Tuple[Tuple[int, int], np.ndarray]] = []
        self.is_calibrated = False
        self.calibration_matrix = None
        
        # Previous gaze for exponential smoothing
        self.prev_screen_point = None
        
        # Camera
        self.camera_id = camera_id
        self.cap = None
        
        # Performance tracking
        self.frame_times: List[float] = []
    
    def _ensure_model_exists(self):
        """Download the face landmarker model if it doesn't exist."""
        if not os.path.exists(self.MODEL_PATH):
            print(f"Downloading face landmarker model...")
            try:
                urllib.request.urlretrieve(self.MODEL_URL, self.MODEL_PATH)
                print(f"Model downloaded successfully!")
            except Exception as e:
                print(f"Error downloading model: {e}")
                print(f"Please manually download from: {self.MODEL_URL}")
                print(f"And save as: {self.MODEL_PATH}")
                raise
        
    def start_camera(self, width: int = 1280, height: int = 720, fps: int = 30) -> bool:
        """
        Start the camera capture.
        
        Args:
            width: Camera frame width
            height: Camera frame height
            fps: Target frame rate
            
        Returns:
            True if camera started successfully
        """
        self.cap = cv2.VideoCapture(self.camera_id)
        
        if not self.cap.isOpened():
            print(f"Error: Could not open camera {self.camera_id}")
            return False
        
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self.cap.set(cv2.CAP_PROP_FPS, fps)
        
        return True
    
    def stop_camera(self):
        """Release the camera."""
        if self.cap is not None:
            self.cap.release()
            self.cap = None
    
    def _get_iris_position(
        self,
        landmarks,
        eye_outer_idx: int,
        eye_inner_idx: int,
        iris_center_idx: int,
        frame_width: int,
        frame_height: int
    ) -> Tuple[Optional[np.ndarray], Optional[Tuple[float, float]]]:
        """
        Calculate normalized iris position within the eye.
        
        Returns gaze direction as a normalized vector and iris center coordinates.
        Falls back to eye center estimation if iris landmarks aren't available.
        """
        try:
            # Get landmark positions (new API uses direct indexing)
            outer = landmarks[eye_outer_idx]
            inner = landmarks[eye_inner_idx]
            
            # Convert to pixel coordinates
            outer_px = np.array([outer.x * frame_width, outer.y * frame_height])
            inner_px = np.array([inner.x * frame_width, inner.y * frame_height])
            
            # Calculate eye width
            eye_width = np.linalg.norm(inner_px - outer_px)
            
            if eye_width < 1:
                return None, None
            
            eye_center = (outer_px + inner_px) / 2
            
            # Try to use iris landmarks if available (indices 468-477)
            if iris_center_idx < len(landmarks):
                iris = landmarks[iris_center_idx]
                iris_px = np.array([iris.x * frame_width, iris.y * frame_height])
            else:
                # Fallback: estimate iris position from eye contour landmarks
                # Use additional eye landmarks to estimate pupil position
                # Left eye: use landmarks around the eye to estimate center
                # This is less accurate but works without iris tracking
                if eye_outer_idx == self.LEFT_EYE_OUTER:
                    # Left eye - use top and bottom landmarks
                    top = landmarks[self.LEFT_EYE_TOP]
                    bottom = landmarks[self.LEFT_EYE_BOTTOM]
                else:
                    # Right eye
                    top = landmarks[self.RIGHT_EYE_TOP]
                    bottom = landmarks[self.RIGHT_EYE_BOTTOM]
                
                top_px = np.array([top.x * frame_width, top.y * frame_height])
                bottom_px = np.array([bottom.x * frame_width, bottom.y * frame_height])
                
                # Estimate iris as center of eye region
                iris_px = (outer_px + inner_px + top_px + bottom_px) / 4
            
            # Normalized position (-1 to 1 range)
            # Apply sensitivity multipliers to reduce required eye movement
            gaze_x = (iris_px[0] - eye_center[0]) / (eye_width / 2) * self.sensitivity_x
            gaze_y = (iris_px[1] - eye_center[1]) / (eye_width / 4) * self.sensitivity_y
            
            # Apply offset correction (helps with camera angle / head position bias)
            gaze_x = gaze_x + self.offset_x
            gaze_y = gaze_y + self.offset_y
            
            # Clamp values
            gaze_x = np.clip(gaze_x, -1, 1)
            gaze_y = np.clip(gaze_y, -1, 1)
            
            return np.array([gaze_x, gaze_y]), (iris_px[0], iris_px[1])
            
        except (IndexError, AttributeError) as e:
            return None, None
    
    def _detect_blink(self, landmarks, frame_height: int) -> Tuple[bool, bool]:
        """Detect if eyes are blinking (closed)."""
        try:
            # Left eye aspect ratio
            left_top = landmarks[self.LEFT_EYE_TOP].y * frame_height
            left_bottom = landmarks[self.LEFT_EYE_BOTTOM].y * frame_height
            left_ear = abs(left_bottom - left_top)
            
            # Right eye aspect ratio
            right_top = landmarks[self.RIGHT_EYE_TOP].y * frame_height
            right_bottom = landmarks[self.RIGHT_EYE_BOTTOM].y * frame_height
            right_ear = abs(right_bottom - right_top)
            
            # Threshold for blink detection
            blink_threshold = 5  # pixels
            
            left_blink = left_ear < blink_threshold
            right_blink = right_ear < blink_threshold
            
            return left_blink, right_blink
            
        except (IndexError, AttributeError):
            return False, False
    
    def process_frame(self, frame: np.ndarray) -> Tuple[GazeData, np.ndarray]:
        """
        Process a single frame and estimate gaze.
        
        Args:
            frame: BGR image from camera
            
        Returns:
            Tuple of (GazeData, annotated frame)
        """
        start_time = time.time()
        
        frame_height, frame_width = frame.shape[:2]
        gaze_data = GazeData()
        
        # Convert to RGB for MediaPipe
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Create MediaPipe Image
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        
        # Process with MediaPipe Face Landmarker
        results = self.face_landmarker.detect(mp_image)
        
        if results.face_landmarks and len(results.face_landmarks) > 0:
            landmarks = results.face_landmarks[0]
            
            # Debug: show landmark count on first detection
            if not hasattr(self, '_landmark_count_shown'):
                num_landmarks = len(landmarks)
                iris_available = num_landmarks > 468
                print(f"Face detected with {num_landmarks} landmarks")
                if iris_available:
                    print("Iris landmarks available (468-477)")
                else:
                    print("Using eye contour fallback (iris landmarks not in model)")
                self._landmark_count_shown = True
            
            # Detect blinks
            left_blink, right_blink = self._detect_blink(landmarks, frame_height)
            
            # Get iris positions
            if not left_blink:
                left_gaze, left_iris = self._get_iris_position(
                    landmarks,
                    self.LEFT_EYE_OUTER,
                    self.LEFT_EYE_INNER,
                    self.LEFT_IRIS_CENTER,
                    frame_width,
                    frame_height
                )
                if left_gaze is not None:
                    # Apply Kalman filter
                    gaze_data.left_gaze = self.left_kalman.update(left_gaze)
                    gaze_data.left_iris_center = left_iris
            
            if not right_blink:
                right_gaze, right_iris = self._get_iris_position(
                    landmarks,
                    self.RIGHT_EYE_OUTER,
                    self.RIGHT_EYE_INNER,
                    self.RIGHT_IRIS_CENTER,
                    frame_width,
                    frame_height
                )
                if right_gaze is not None:
                    # Apply Kalman filter
                    gaze_data.right_gaze = self.right_kalman.update(right_gaze)
                    gaze_data.right_iris_center = right_iris
            
            # Combine gaze from both eyes
            if gaze_data.left_gaze is not None and gaze_data.right_gaze is not None:
                combined = (gaze_data.left_gaze + gaze_data.right_gaze) / 2
                gaze_data.combined_gaze = self.combined_kalman.update(combined)
                gaze_data.confidence = 1.0
            elif gaze_data.left_gaze is not None:
                gaze_data.combined_gaze = gaze_data.left_gaze
                gaze_data.confidence = 0.7
            elif gaze_data.right_gaze is not None:
                gaze_data.combined_gaze = gaze_data.right_gaze
                gaze_data.confidence = 0.7
            
            # Map to screen coordinates
            if gaze_data.combined_gaze is not None:
                screen_x = int((gaze_data.combined_gaze[0] + 1) / 2 * self.screen_width)
                screen_y = int((gaze_data.combined_gaze[1] + 1) / 2 * self.screen_height)
                
                # Apply exponential smoothing
                if self.prev_screen_point is not None:
                    screen_x = int(
                        self.smoothing_factor * screen_x +
                        (1 - self.smoothing_factor) * self.prev_screen_point[0]
                    )
                    screen_y = int(
                        self.smoothing_factor * screen_y +
                        (1 - self.smoothing_factor) * self.prev_screen_point[1]
                    )
                
                gaze_data.screen_point = (screen_x, screen_y)
                self.prev_screen_point = gaze_data.screen_point
            
            # Draw annotations
            frame = self._draw_annotations(frame, landmarks, gaze_data, frame_width, frame_height)
        
        # Track performance
        elapsed = time.time() - start_time
        self.frame_times.append(elapsed)
        if len(self.frame_times) > 30:
            self.frame_times.pop(0)
        
        return gaze_data, frame
    
    def _draw_annotations(
        self,
        frame: np.ndarray,
        landmarks,
        gaze_data: GazeData,
        frame_width: int,
        frame_height: int
    ) -> np.ndarray:
        """Draw gaze visualization on the frame."""
        
        # Draw iris centers
        if gaze_data.left_iris_center:
            cv2.circle(
                frame,
                (int(gaze_data.left_iris_center[0]), int(gaze_data.left_iris_center[1])),
                3, (0, 255, 0), -1
            )
        
        if gaze_data.right_iris_center:
            cv2.circle(
                frame,
                (int(gaze_data.right_iris_center[0]), int(gaze_data.right_iris_center[1])),
                3, (0, 255, 0), -1
            )
        
        # Draw gaze direction indicator
        if gaze_data.combined_gaze is not None:
            # Draw a small gaze indicator in the corner
            indicator_size = 100
            indicator_x = frame_width - indicator_size - 20
            indicator_y = 20
            
            # Draw indicator background
            cv2.rectangle(
                frame,
                (indicator_x, indicator_y),
                (indicator_x + indicator_size, indicator_y + indicator_size),
                (50, 50, 50), -1
            )
            cv2.rectangle(
                frame,
                (indicator_x, indicator_y),
                (indicator_x + indicator_size, indicator_y + indicator_size),
                (255, 255, 255), 2
            )
            
            # Draw crosshairs for reference
            center_x = indicator_x + indicator_size // 2
            center_y = indicator_y + indicator_size // 2
            cv2.line(frame, (indicator_x, center_y), (indicator_x + indicator_size, center_y), (100, 100, 100), 1)
            cv2.line(frame, (center_x, indicator_y), (center_x, indicator_y + indicator_size), (100, 100, 100), 1)
            
            # Draw gaze point (already amplified by sensitivity)
            gaze_px = int(indicator_x + (gaze_data.combined_gaze[0] + 1) / 2 * indicator_size)
            gaze_py = int(indicator_y + (gaze_data.combined_gaze[1] + 1) / 2 * indicator_size)
            
            # Clamp to indicator bounds for display
            gaze_px = max(indicator_x + 5, min(indicator_x + indicator_size - 5, gaze_px))
            gaze_py = max(indicator_y + 5, min(indicator_y + indicator_size - 5, gaze_py))
            
            cv2.circle(frame, (gaze_px, gaze_py), 8, (0, 255, 255), -1)
            cv2.circle(frame, (gaze_px, gaze_py), 10, (255, 255, 255), 2)
        
        # Draw performance stats
        if self.frame_times:
            avg_time = sum(self.frame_times) / len(self.frame_times)
            fps = 1.0 / avg_time if avg_time > 0 else 0
            latency_ms = avg_time * 1000
            
            cv2.putText(
                frame,
                f"FPS: {fps:.1f} | Latency: {latency_ms:.1f}ms",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7, (0, 255, 0), 2
            )
            
            if gaze_data.confidence > 0:
                cv2.putText(
                    frame,
                    f"Confidence: {gaze_data.confidence:.0%}",
                    (10, 60),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7, (0, 255, 0), 2
                )
        
        return frame
    
    def get_average_latency(self) -> float:
        """Get average processing latency in milliseconds."""
        if not self.frame_times:
            return 0
        return (sum(self.frame_times) / len(self.frame_times)) * 1000
    
    def reset_filters(self):
        """Reset all Kalman filters."""
        self.left_kalman.reset()
        self.right_kalman.reset()
        self.combined_kalman.reset()
        self.prev_screen_point = None
    
    def set_sensitivity(self, x: float = None, y: float = None):
        """
        Adjust gaze sensitivity.
        
        Args:
            x: Horizontal sensitivity (higher = less eye movement needed)
            y: Vertical sensitivity (higher = less eye movement needed)
        """
        if x is not None:
            self.sensitivity_x = max(0.5, min(5.0, x))
        if y is not None:
            self.sensitivity_y = max(0.5, min(5.0, y))
    
    def get_sensitivity(self) -> Tuple[float, float]:
        """Get current sensitivity values."""
        return (self.sensitivity_x, self.sensitivity_y)
    
    def set_offset(self, x: float = None, y: float = None):
        """
        Adjust gaze offset (for correcting camera angle / head position bias).
        
        Args:
            x: Horizontal offset (-1 to 1, positive = shift gaze right)
            y: Vertical offset (-1 to 1, positive = shift gaze down)
        """
        if x is not None:
            self.offset_x = max(-1.0, min(1.0, x))
        if y is not None:
            self.offset_y = max(-1.0, min(1.0, y))
    
    def get_offset(self) -> Tuple[float, float]:
        """Get current offset values."""
        return (self.offset_x, self.offset_y)


def run_demo():
    """Run a live demo of the eye gaze tracker."""
    print("=" * 60)
    print("Eye Gaze Tracker Demo")
    print("Based on MediaPipe Iris + Kalman Filters")
    print("=" * 60)
    print("\nControls:")
    print("  q        - Quit")
    print("  r        - Reset Kalman filters")
    print("  c        - Save screenshot")
    print("  +/-      - Increase/decrease overall sensitivity")
    print("  Arrow keys - Adjust gaze offset (for calibration)")
    print("             Up/Down = vertical offset")
    print("             Left/Right = horizontal offset")
    print("  0        - Reset offset to zero")
    print("\n")
    
    # Initialize tracker with higher default sensitivity and downward offset
    tracker = EyeGazeTracker(
        camera_id=0,
        screen_width=1920,
        screen_height=1080,
        process_noise=1e-4,
        measurement_noise=1e-2,
        smoothing_factor=0.4,
        sensitivity_x=2.5,  # Amplify horizontal gaze
        sensitivity_y=3.0,  # Amplify vertical gaze more (it's harder to detect)
        offset_x=0.0,
        offset_y=0.3       # Shift gaze down to compensate for upward bias
    )
    
    # Start camera
    if not tracker.start_camera(width=1280, height=720, fps=30):
        print("Failed to start camera!")
        return
    
    print("Camera started successfully!")
    print("Position your face in front of the camera...")
    print(f"Initial sensitivity: X={tracker.sensitivity_x:.1f}, Y={tracker.sensitivity_y:.1f}")
    print(f"Initial offset: X={tracker.offset_x:.2f}, Y={tracker.offset_y:.2f}")
    print("\nTip: If gaze is stuck at top, press DOWN arrow to increase Y offset")
    print("     If gaze is stuck at bottom, press UP arrow to decrease Y offset")
    
    cv2.namedWindow("Eye Gaze Tracker", cv2.WINDOW_NORMAL)
    
    screenshot_count = 0
    
    try:
        while True:
            ret, frame = tracker.cap.read()
            if not ret:
                print("Failed to read frame")
                break
            
            # Mirror the frame for more intuitive interaction
            frame = cv2.flip(frame, 1)
            
            # Process frame
            gaze_data, annotated_frame = tracker.process_frame(frame)
            
            # Display gaze info
            if gaze_data.screen_point:
                cv2.putText(
                    annotated_frame,
                    f"Screen: ({gaze_data.screen_point[0]}, {gaze_data.screen_point[1]})",
                    (10, 90),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7, (255, 255, 0), 2
                )
            
            # Display sensitivity and offset
            sens_x, sens_y = tracker.get_sensitivity()
            off_x, off_y = tracker.get_offset()
            cv2.putText(
                annotated_frame,
                f"Sens: X={sens_x:.1f} Y={sens_y:.1f} | Offset: X={off_x:+.2f} Y={off_y:+.2f}",
                (10, 120),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55, (200, 200, 200), 2
            )
            cv2.putText(
                annotated_frame,
                "Arrow keys=offset, +/-=sensitivity, 0=reset offset",
                (10, 145),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.45, (150, 150, 150), 1
            )
            
            # Show frame
            cv2.imshow("Eye Gaze Tracker", annotated_frame)
            
            # Handle key presses
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('r'):
                tracker.reset_filters()
                print("Kalman filters reset!")
            elif key == ord('c'):
                filename = f"gaze_screenshot_{screenshot_count}.png"
                cv2.imwrite(filename, annotated_frame)
                print(f"Screenshot saved: {filename}")
                screenshot_count += 1
            # Sensitivity adjustments
            elif key == ord('+') or key == ord('='):
                tracker.set_sensitivity(sens_x + 0.2, sens_y + 0.2)
                print(f"Sensitivity: X={tracker.sensitivity_x:.1f}, Y={tracker.sensitivity_y:.1f}")
            elif key == ord('-') or key == ord('_'):
                tracker.set_sensitivity(sens_x - 0.2, sens_y - 0.2)
                print(f"Sensitivity: X={tracker.sensitivity_x:.1f}, Y={tracker.sensitivity_y:.1f}")
            # Offset adjustments with arrow keys
            elif key == 82 or key == 0:  # Up arrow
                tracker.set_offset(y=off_y - 0.05)
                print(f"Y Offset: {tracker.offset_y:+.2f} (gaze shifted UP)")
            elif key == 84 or key == 1:  # Down arrow
                tracker.set_offset(y=off_y + 0.05)
                print(f"Y Offset: {tracker.offset_y:+.2f} (gaze shifted DOWN)")
            elif key == 81 or key == 2:  # Left arrow
                tracker.set_offset(x=off_x - 0.05)
                print(f"X Offset: {tracker.offset_x:+.2f} (gaze shifted LEFT)")
            elif key == 83 or key == 3:  # Right arrow
                tracker.set_offset(x=off_x + 0.05)
                print(f"X Offset: {tracker.offset_x:+.2f} (gaze shifted RIGHT)")
            elif key == ord('0'):
                tracker.set_offset(0.0, 0.0)
                print("Offset reset to zero")
    
    finally:
        tracker.stop_camera()
        cv2.destroyAllWindows()
        
        print(f"\nSession stats:")
        print(f"  Average latency: {tracker.get_average_latency():.1f}ms")
        print(f"  Final sensitivity: X={tracker.sensitivity_x:.1f}, Y={tracker.sensitivity_y:.1f}")
        print(f"  Final offset: X={tracker.offset_x:+.2f}, Y={tracker.offset_y:+.2f}")


if __name__ == "__main__":
    run_demo()
