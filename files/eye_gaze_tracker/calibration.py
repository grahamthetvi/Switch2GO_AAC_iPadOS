"""
Calibration Tool for Eye Gaze Tracker

This module provides a calibration procedure to improve the accuracy
of gaze-to-screen coordinate mapping. Users look at specified points
on the screen while the system records their gaze vectors.

Supports two calibration modes:
1. AFFINE (linear): Simple and fast, but less accurate at edges
   screen_x = a₀ + a₁·gx + a₂·gy
   screen_y = b₀ + b₁·gx + b₂·gy

2. POLYNOMIAL (2nd order): More accurate, handles nonlinear eye-to-screen mapping
   screen_x = a₀ + a₁·gx + a₂·gy + a₃·gx² + a₄·gy² + a₅·gx·gy
   screen_y = b₀ + b₁·gx + b₂·gy + b₃·gx² + b₄·gy² + b₅·gx·gy
"""

import cv2
import numpy as np
import time
from enum import Enum
from typing import List, Tuple, Optional
from gaze_tracker import EyeGazeTracker, GazeData


class CalibrationMode(Enum):
    """Calibration mode for gaze-to-screen mapping."""
    AFFINE = "affine"      # Linear: 3 coefficients per axis
    POLYNOMIAL = "polynomial"  # 2nd order: 6 coefficients per axis


class CalibrationTool:
    """
    Interactive calibration tool for eye gaze tracking.
    
    Displays calibration points on screen and records gaze data
    to compute an accurate mapping from gaze vectors to screen coordinates.
    """
    
    def __init__(
        self,
        tracker: EyeGazeTracker,
        num_points: int = 9,
        samples_per_point: int = 30,
        screen_width: int = 1920,
        screen_height: int = 1080,
        mode: CalibrationMode = CalibrationMode.POLYNOMIAL
    ):
        """
        Initialize the calibration tool.
        
        Args:
            tracker: EyeGazeTracker instance
            num_points: Number of calibration points (5 or 9)
            samples_per_point: Number of gaze samples to collect per point
            screen_width: Screen width in pixels
            screen_height: Screen height in pixels
            mode: Calibration mode (AFFINE or POLYNOMIAL)
        """
        self.tracker = tracker
        self.num_points = num_points
        self.samples_per_point = samples_per_point
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.mode = mode
        
        # Generate calibration point positions
        self.calibration_points = self._generate_points()
        
        # Storage for calibration data
        self.calibration_data: List[Tuple[Tuple[int, int], List[np.ndarray]]] = []
        
        # Calibration result
        self.transform_matrix: Optional[np.ndarray] = None
        self.transform_x: Optional[np.ndarray] = None
        self.transform_y: Optional[np.ndarray] = None
        
    def _generate_points(self) -> List[Tuple[int, int]]:
        """Generate calibration point positions."""
        margin_x = int(self.screen_width * 0.1)
        margin_y = int(self.screen_height * 0.1)
        
        if self.num_points == 5:
            # 5-point calibration: corners + center
            return [
                (margin_x, margin_y),  # Top-left
                (self.screen_width - margin_x, margin_y),  # Top-right
                (self.screen_width // 2, self.screen_height // 2),  # Center
                (margin_x, self.screen_height - margin_y),  # Bottom-left
                (self.screen_width - margin_x, self.screen_height - margin_y),  # Bottom-right
            ]
        else:
            # 9-point calibration: 3x3 grid
            points = []
            for row in range(3):
                for col in range(3):
                    x = margin_x + col * (self.screen_width - 2 * margin_x) // 2
                    y = margin_y + row * (self.screen_height - 2 * margin_y) // 2
                    points.append((x, y))
            return points
    
    def run_calibration(self) -> bool:
        """
        Run the interactive calibration procedure.
        
        Returns:
            True if calibration was successful
        """
        # Create fullscreen window
        cv2.namedWindow("Calibration", cv2.WND_PROP_FULLSCREEN)
        cv2.setWindowProperty("Calibration", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
        
        self.calibration_data = []
        
        print("\n" + "=" * 50)
        print("CALIBRATION PROCEDURE")
        print("=" * 50)
        print("\nInstructions:")
        print("1. Look at each dot as it appears on screen")
        print("2. Keep your head still")
        print("3. Press SPACE when ready to record each point")
        print("4. Press ESC to cancel calibration")
        print("\n")
        
        try:
            for i, point in enumerate(self.calibration_points):
                print(f"Point {i + 1}/{len(self.calibration_points)}: {point}")
                
                # Show the calibration point
                success = self._collect_point_data(point, i)
                
                if not success:
                    print("Calibration cancelled.")
                    cv2.destroyWindow("Calibration")
                    return False
                
                # Brief pause between points
                time.sleep(0.3)
            
            # Compute calibration matrix
            self._compute_calibration()
            
            print("\nCalibration complete!")
            print(f"Collected data from {len(self.calibration_data)} points")
            
            cv2.destroyWindow("Calibration")
            return True
            
        except Exception as e:
            print(f"Calibration error: {e}")
            cv2.destroyWindow("Calibration")
            return False
    
    def _collect_point_data(self, point: Tuple[int, int], index: int) -> bool:
        """Collect gaze data for a single calibration point."""
        samples: List[np.ndarray] = []
        collecting = False
        
        while True:
            # Read frame
            ret, frame = self.tracker.cap.read()
            if not ret:
                continue
            
            frame = cv2.flip(frame, 1)
            
            # Process gaze
            gaze_data, _ = self.tracker.process_frame(frame)
            
            # Create calibration display
            display = np.zeros((self.screen_height, self.screen_width, 3), dtype=np.uint8)
            
            # Draw calibration point
            point_color = (0, 255, 0) if collecting else (255, 255, 255)
            cv2.circle(display, point, 30, point_color, -1)
            cv2.circle(display, point, 35, (100, 100, 100), 3)
            cv2.circle(display, point, 5, (0, 0, 0), -1)  # Center dot
            
            # Draw instructions
            instruction = "Press SPACE to start recording" if not collecting else f"Recording... {len(samples)}/{self.samples_per_point}"
            cv2.putText(
                display, instruction,
                (self.screen_width // 2 - 200, self.screen_height - 50),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (200, 200, 200), 2
            )
            
            cv2.putText(
                display, f"Point {index + 1}/{len(self.calibration_points)}",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (150, 150, 150), 2
            )
            
            # Show camera preview in corner
            preview = cv2.resize(frame, (320, 240))
            display[20:260, self.screen_width - 340:self.screen_width - 20] = preview
            
            cv2.imshow("Calibration", display)
            
            # Handle input
            key = cv2.waitKey(1) & 0xFF
            
            if key == 27:  # ESC
                return False
            elif key == ord(' ') and not collecting:
                collecting = True
                self.tracker.reset_filters()  # Reset for fresh data
            
            # Collect samples
            if collecting and gaze_data.combined_gaze is not None:
                samples.append(gaze_data.combined_gaze.copy())
                
                if len(samples) >= self.samples_per_point:
                    # Average the samples
                    avg_gaze = np.mean(samples, axis=0)
                    self.calibration_data.append((point, samples))
                    print(f"  Collected {len(samples)} samples, avg gaze: {avg_gaze}")
                    return True
        
        return False
    
    def _compute_calibration(self):
        """Compute the gaze-to-screen transformation based on calibration mode."""
        min_points = 6 if self.mode == CalibrationMode.POLYNOMIAL else 4
        if len(self.calibration_data) < min_points:
            print(f"Warning: Not enough calibration points (need {min_points}, have {len(self.calibration_data)})")
            return
        
        # Prepare data for least squares fitting
        gaze_points = []
        screen_points = []
        
        for screen_point, samples in self.calibration_data:
            avg_gaze = np.mean(samples, axis=0)
            gaze_points.append(avg_gaze)
            screen_points.append(screen_point)
        
        gaze_points = np.array(gaze_points)
        screen_points = np.array(screen_points)
        
        n = len(gaze_points)
        
        if self.mode == CalibrationMode.POLYNOMIAL:
            # Build design matrix for 2nd order polynomial:
            # [1, gx, gy, gx², gy², gx·gy]
            A = np.column_stack([
                np.ones(n),
                gaze_points[:, 0],          # gx
                gaze_points[:, 1],          # gy
                gaze_points[:, 0] ** 2,     # gx²
                gaze_points[:, 1] ** 2,     # gy²
                gaze_points[:, 0] * gaze_points[:, 1]  # gx·gy
            ])
            print(f"Using polynomial calibration (6 coefficients)")
        else:
            # Build design matrix for affine (linear):
            # [1, gx, gy]
            A = np.column_stack([np.ones(n), gaze_points])
            print(f"Using affine calibration (3 coefficients)")
        
        # Solve for x and y separately using least squares
        self.transform_x, _, _, _ = np.linalg.lstsq(A, screen_points[:, 0], rcond=None)
        self.transform_y, _, _, _ = np.linalg.lstsq(A, screen_points[:, 1], rcond=None)
        
        # Store combined transform
        self.transform_matrix = np.vstack([self.transform_x, self.transform_y])
        
        # Calculate calibration error
        errors = []
        for i, (screen_point, samples) in enumerate(self.calibration_data):
            avg_gaze = np.mean(samples, axis=0)
            predicted = self.gaze_to_screen(avg_gaze)
            error = np.sqrt((predicted[0] - screen_point[0])**2 + 
                          (predicted[1] - screen_point[1])**2)
            errors.append(error)
        
        avg_error = np.mean(errors)
        print(f"Calibration error ({self.mode.value}): {avg_error:.1f} pixels average")
        
        # Log coefficients
        if self.mode == CalibrationMode.POLYNOMIAL:
            print(f"Transform X: {self.transform_x[0]:.3f} + {self.transform_x[1]:.3f}·gx + {self.transform_x[2]:.3f}·gy + "
                  f"{self.transform_x[3]:.3f}·gx² + {self.transform_x[4]:.3f}·gy² + {self.transform_x[5]:.3f}·gx·gy")
            print(f"Transform Y: {self.transform_y[0]:.3f} + {self.transform_y[1]:.3f}·gx + {self.transform_y[2]:.3f}·gy + "
                  f"{self.transform_y[3]:.3f}·gx² + {self.transform_y[4]:.3f}·gy² + {self.transform_y[5]:.3f}·gx·gy")
        else:
            print(f"Transform X: {self.transform_x[0]:.3f} + {self.transform_x[1]:.3f}·gx + {self.transform_x[2]:.3f}·gy")
            print(f"Transform Y: {self.transform_y[0]:.3f} + {self.transform_y[1]:.3f}·gx + {self.transform_y[2]:.3f}·gy")
    
    def gaze_to_screen(self, gaze: np.ndarray) -> Tuple[int, int]:
        """
        Convert gaze vector to screen coordinates using calibration.
        
        Args:
            gaze: Normalized gaze vector [x, y]
            
        Returns:
            Screen coordinates (x, y)
        """
        if self.transform_matrix is None or self.transform_x is None or self.transform_y is None:
            # Fall back to simple linear mapping
            x = int((gaze[0] + 1) / 2 * self.screen_width)
            y = int((gaze[1] + 1) / 2 * self.screen_height)
            return (x, y)
        
        gx, gy = gaze[0], gaze[1]
        
        if self.mode == CalibrationMode.POLYNOMIAL:
            # Apply polynomial transform:
            # screen = a₀ + a₁·gx + a₂·gy + a₃·gx² + a₄·gy² + a₅·gx·gy
            gaze_features = np.array([1, gx, gy, gx*gx, gy*gy, gx*gy])
        else:
            # Apply affine transform:
            # screen = a₀ + a₁·gx + a₂·gy
            gaze_features = np.array([1, gx, gy])
        
        x = int(np.dot(self.transform_x, gaze_features))
        y = int(np.dot(self.transform_y, gaze_features))
        
        # Clamp to screen bounds
        x = max(0, min(self.screen_width - 1, x))
        y = max(0, min(self.screen_height - 1, y))
        
        return (x, y)
    
    def save_calibration(self, filename: str = "gaze_calibration.npz"):
        """Save calibration data to file."""
        if self.transform_matrix is not None:
            np.savez(
                filename,
                transform_x=self.transform_x,
                transform_y=self.transform_y,
                calibration_points=np.array(self.calibration_points, dtype=object),
                screen_width=self.screen_width,
                screen_height=self.screen_height,
                mode=self.mode.value
            )
            print(f"Calibration ({self.mode.value}) saved to {filename}")
            return True
        return False
    
    def load_calibration(self, filename: str = "gaze_calibration.npz") -> bool:
        """Load calibration data from file."""
        try:
            data = np.load(filename, allow_pickle=True)
            self.transform_x = data['transform_x']
            self.transform_y = data['transform_y']
            self.transform_matrix = np.vstack([self.transform_x, self.transform_y])
            
            # Load mode if available (backward compatibility)
            if 'mode' in data:
                mode_str = str(data['mode'])
                self.mode = CalibrationMode.POLYNOMIAL if mode_str == 'polynomial' else CalibrationMode.AFFINE
            else:
                # Infer mode from coefficient count
                self.mode = CalibrationMode.POLYNOMIAL if len(self.transform_x) == 6 else CalibrationMode.AFFINE
            
            print(f"Calibration ({self.mode.value}) loaded from {filename}")
            print(f"  Transform X: {self.transform_x}")
            print(f"  Transform Y: {self.transform_y}")
            return True
        except Exception as e:
            print(f"Failed to load calibration: {e}")
            return False


def run_calibration_demo():
    """Run a calibration demonstration."""
    print("Eye Gaze Calibration Tool")
    print("=" * 40)
    print("Using polynomial calibration for better accuracy at screen edges")
    print("")
    
    # Create tracker with sensitivity and offset settings
    tracker = EyeGazeTracker(
        camera_id=0,
        screen_width=1920,
        screen_height=1080,
        sensitivity_x=2.5,
        sensitivity_y=3.0,
        offset_x=0.0,
        offset_y=0.3
    )
    
    if not tracker.start_camera():
        print("Failed to start camera!")
        return
    
    # Create calibration tool with polynomial mode
    calibrator = CalibrationTool(
        tracker,
        num_points=9,
        samples_per_point=30,
        mode=CalibrationMode.POLYNOMIAL  # Use polynomial for better accuracy
    )
    
    # Run calibration
    success = calibrator.run_calibration()
    
    if success:
        calibrator.save_calibration("gaze_calibration.npz")
        
        # Test the calibration
        print("\nTesting calibration - move your eyes around!")
        print("Press 'q' to quit\n")
        
        cv2.namedWindow("Gaze Test", cv2.WINDOW_NORMAL)
        
        while True:
            ret, frame = tracker.cap.read()
            if not ret:
                break
            
            frame = cv2.flip(frame, 1)
            gaze_data, annotated = tracker.process_frame(frame)
            
            if gaze_data.combined_gaze is not None:
                # Use calibrated coordinates
                screen_point = calibrator.gaze_to_screen(gaze_data.combined_gaze)
                
                cv2.putText(
                    annotated,
                    f"Calibrated: ({screen_point[0]}, {screen_point[1]})",
                    (10, 120),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7, (0, 255, 255), 2
                )
            
            cv2.imshow("Gaze Test", annotated)
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        
        cv2.destroyAllWindows()
    
    tracker.stop_camera()


if __name__ == "__main__":
    run_calibration_demo()
