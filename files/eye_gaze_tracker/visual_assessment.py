"""
Visual Assessment Tool for Eye Gaze Tracking

Designed for CVI (Cortical Visual Impairment) assessment and AAC applications.
Displays visual targets and tracks gaze patterns to assess visual attention
and preference.

Features:
- Multiple target presentation modes
- Gaze dwell detection for selection
- Data logging for assessment reports
- Configurable target sizes and colors (important for CVI)
- Calibration integration for accurate gaze mapping
"""

import cv2
import numpy as np
import time
import json
import os
from datetime import datetime
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass, asdict
from gaze_tracker import EyeGazeTracker
from calibration import CalibrationTool


@dataclass
class GazeEvent:
    """Record of a gaze event."""
    timestamp: float
    target_id: Optional[str]
    gaze_x: float
    gaze_y: float
    screen_x: int
    screen_y: int
    dwell_time: float
    selected: bool


@dataclass 
class Target:
    """Visual target for assessment."""
    id: str
    x: int
    y: int
    width: int
    height: int
    color: Tuple[int, int, int]
    shape: str  # 'circle', 'square', 'image'
    image_path: Optional[str] = None


class QuickCalibration:
    """
    Quick 5-point calibration to determine offset correction.
    Shows targets at center, top, bottom, left, right and measures bias.
    """
    
    def __init__(
        self,
        tracker: EyeGazeTracker,
        screen_width: int = 1920,
        screen_height: int = 1080
    ):
        self.tracker = tracker
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # Calibration points: center, top, bottom, left, right
        margin = 150
        self.cal_points = [
            ("center", screen_width // 2, screen_height // 2),
            ("top", screen_width // 2, margin),
            ("bottom", screen_width // 2, screen_height - margin),
            ("left", margin, screen_height // 2),
            ("right", screen_width - margin, screen_height // 2),
        ]
        
    def run(self, samples_per_point: int = 20) -> Tuple[float, float]:
        """
        Run quick calibration and return computed offsets.
        
        Returns:
            Tuple of (offset_x, offset_y) to apply
        """
        print("\n" + "=" * 50)
        print("QUICK CALIBRATION")
        print("=" * 50)
        print("Look at each target as it appears.")
        print("Press SPACE when you're looking at the target.")
        print("Press ESC to skip calibration.\n")
        
        cv2.namedWindow("Calibration", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("Calibration", self.screen_width, self.screen_height)
        
        measurements = []
        
        try:
            for name, target_x, target_y in self.cal_points:
                print(f"Look at: {name.upper()}")
                
                result = self._collect_point(name, target_x, target_y, samples_per_point)
                if result is None:
                    print("Calibration cancelled.")
                    cv2.destroyWindow("Calibration")
                    return (self.tracker.offset_x, self.tracker.offset_y)
                
                measurements.append(result)
                time.sleep(0.3)
            
            cv2.destroyWindow("Calibration")
            
            # Compute offsets from measurements
            offset_x, offset_y = self._compute_offsets(measurements)
            
            print(f"\nCalibration complete!")
            print(f"Computed offsets: X={offset_x:+.2f}, Y={offset_y:+.2f}")
            
            return (offset_x, offset_y)
            
        except Exception as e:
            print(f"Calibration error: {e}")
            cv2.destroyWindow("Calibration")
            return (self.tracker.offset_x, self.tracker.offset_y)
    
    def _collect_point(
        self,
        name: str,
        target_x: int,
        target_y: int,
        num_samples: int
    ) -> Optional[Dict]:
        """Collect gaze samples for a single calibration point."""
        
        samples = []
        collecting = False
        
        while True:
            ret, frame = self.tracker.cap.read()
            if not ret:
                continue
            
            frame = cv2.flip(frame, 1)
            gaze_data, _ = self.tracker.process_frame(frame)
            
            # Create display
            display = np.zeros((self.screen_height, self.screen_width, 3), dtype=np.uint8)
            
            # Draw target
            color = (0, 255, 0) if collecting else (0, 255, 255)
            cv2.circle(display, (target_x, target_y), 40, color, -1)
            cv2.circle(display, (target_x, target_y), 45, (255, 255, 255), 3)
            cv2.circle(display, (target_x, target_y), 5, (0, 0, 0), -1)
            
            # Draw instructions
            status = f"Recording: {len(samples)}/{num_samples}" if collecting else "Press SPACE when looking at target"
            cv2.putText(display, status, (self.screen_width//2 - 200, self.screen_height - 50),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (200, 200, 200), 2)
            cv2.putText(display, f"Target: {name.upper()}", (20, 40),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (150, 150, 150), 2)
            
            # Draw current gaze position
            if gaze_data.combined_gaze is not None:
                gx = int((gaze_data.combined_gaze[0] + 1) / 2 * self.screen_width)
                gy = int((gaze_data.combined_gaze[1] + 1) / 2 * self.screen_height)
                cv2.circle(display, (gx, gy), 10, (255, 0, 255), 2)
            
            # Camera preview
            preview = cv2.resize(frame, (240, 180))
            display[20:200, self.screen_width-260:self.screen_width-20] = preview
            
            cv2.imshow("Calibration", display)
            
            key = cv2.waitKey(1) & 0xFF
            
            if key == 27:  # ESC
                return None
            elif key == ord(' ') and not collecting:
                collecting = True
                samples = []
            
            # Collect samples
            if collecting and gaze_data.combined_gaze is not None:
                samples.append({
                    'gaze_x': gaze_data.combined_gaze[0],
                    'gaze_y': gaze_data.combined_gaze[1],
                })
                
                if len(samples) >= num_samples:
                    avg_gaze_x = np.mean([s['gaze_x'] for s in samples])
                    avg_gaze_y = np.mean([s['gaze_y'] for s in samples])
                    
                    # Expected normalized position
                    expected_x = (target_x / self.screen_width) * 2 - 1
                    expected_y = (target_y / self.screen_height) * 2 - 1
                    
                    return {
                        'name': name,
                        'target_x': target_x,
                        'target_y': target_y,
                        'expected_x': expected_x,
                        'expected_y': expected_y,
                        'measured_x': avg_gaze_x,
                        'measured_y': avg_gaze_y,
                        'error_x': expected_x - avg_gaze_x,
                        'error_y': expected_y - avg_gaze_y,
                    }
        
        return None
    
    def _compute_offsets(self, measurements: List[Dict]) -> Tuple[float, float]:
        """Compute offset corrections from calibration measurements."""
        
        # Average the errors across all points
        avg_error_x = np.mean([m['error_x'] for m in measurements])
        avg_error_y = np.mean([m['error_y'] for m in measurements])
        
        # The offset should correct for the error
        # Current offset + error correction
        new_offset_x = self.tracker.offset_x + avg_error_x
        new_offset_y = self.tracker.offset_y + avg_error_y
        
        # Clamp to reasonable range
        new_offset_x = np.clip(new_offset_x, -1.0, 1.0)
        new_offset_y = np.clip(new_offset_y, -1.0, 1.0)
        
        # Print detailed results
        print("\nCalibration measurements:")
        for m in measurements:
            print(f"  {m['name']:8s}: expected ({m['expected_x']:+.2f}, {m['expected_y']:+.2f}) "
                  f"measured ({m['measured_x']:+.2f}, {m['measured_y']:+.2f}) "
                  f"error ({m['error_x']:+.2f}, {m['error_y']:+.2f})")
        
        return (new_offset_x, new_offset_y)


class VisualAssessmentTool:
    """
    Interactive visual assessment tool using eye gaze tracking.
    
    Presents visual targets and measures gaze behavior for:
    - Visual attention assessment
    - CVI screening (color/size preferences)
    - AAC target selection training
    """
    
    def __init__(
        self,
        tracker: EyeGazeTracker,
        screen_width: int = 1920,
        screen_height: int = 1080,
        background_color: Tuple[int, int, int] = (0, 0, 0),
        dwell_threshold: float = 0.5  # seconds to select
    ):
        """
        Initialize the assessment tool.
        
        Args:
            tracker: EyeGazeTracker instance
            screen_width: Display width
            screen_height: Display height
            background_color: Background color (black recommended for CVI)
            dwell_threshold: Seconds of gaze dwell to trigger selection
        """
        self.tracker = tracker
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.background_color = background_color
        self.dwell_threshold = dwell_threshold
        
        # Calibration support
        self.calibrator: Optional[CalibrationTool] = None
        
        # Targets
        self.targets: List[Target] = []
        
        # Session data
        self.session_start: Optional[float] = None
        self.events: List[GazeEvent] = []
        
        # Current state
        self.current_target: Optional[str] = None
        self.dwell_start: Optional[float] = None
        self.selections: List[str] = []
    
    def load_calibration(self, filename: str = "gaze_calibration.npz") -> bool:
        """
        Load calibration from file.
        
        Args:
            filename: Path to calibration file
            
        Returns:
            True if calibration loaded successfully
        """
        if not os.path.exists(filename):
            print(f"Calibration file not found: {filename}")
            return False
        
        self.calibrator = CalibrationTool(
            self.tracker,
            num_points=9,
            screen_width=self.screen_width,
            screen_height=self.screen_height
        )
        
        if self.calibrator.load_calibration(filename):
            print("Calibration loaded - will use calibrated gaze mapping")
            return True
        else:
            self.calibrator = None
            return False
    
    def run_calibration(self, num_points: int = 9) -> bool:
        """
        Run interactive calibration before assessment.
        
        Args:
            num_points: Number of calibration points (5 or 9)
            
        Returns:
            True if calibration completed successfully
        """
        self.calibrator = CalibrationTool(
            self.tracker,
            num_points=num_points,
            screen_width=self.screen_width,
            screen_height=self.screen_height
        )
        
        success = self.calibrator.run_calibration()
        
        if success:
            self.calibrator.save_calibration("gaze_calibration.npz")
            print("Calibration complete and saved!")
            return True
        else:
            self.calibrator = None
            return False
    
    def get_calibrated_screen_point(self, gaze_data) -> Optional[Tuple[int, int]]:
        """
        Get screen coordinates, using calibration if available.
        
        Args:
            gaze_data: GazeData from tracker
            
        Returns:
            (x, y) screen coordinates or None
        """
        if gaze_data.combined_gaze is None:
            return None
        
        if self.calibrator and self.calibrator.transform_matrix is not None:
            # Use calibrated mapping
            return self.calibrator.gaze_to_screen(gaze_data.combined_gaze)
        else:
            # Fall back to tracker's screen_point
            return gaze_data.screen_point
        
    def add_target(
        self,
        target_id: str,
        x: int,
        y: int,
        width: int = 200,
        height: int = 200,
        color: Tuple[int, int, int] = (255, 255, 0),  # Yellow - good for CVI
        shape: str = 'circle'
    ):
        """Add a visual target."""
        target = Target(
            id=target_id,
            x=x,
            y=y,
            width=width,
            height=height,
            color=color,
            shape=shape
        )
        self.targets.append(target)
        
    def create_grid_layout(
        self,
        rows: int = 2,
        cols: int = 2,
        target_size: int = 200,
        colors: Optional[List[Tuple[int, int, int]]] = None
    ):
        """
        Create a grid of targets for choice-based assessment.
        
        Args:
            rows: Number of rows
            cols: Number of columns
            target_size: Size of each target
            colors: List of colors for targets (cycles if fewer than needed)
        """
        self.targets = []
        
        # Default CVI-friendly colors (high contrast, saturated)
        if colors is None:
            colors = [
                (0, 255, 255),    # Yellow
                (255, 0, 0),      # Blue (BGR)
                (0, 0, 255),      # Red
                (0, 255, 0),      # Green
                (255, 0, 255),    # Magenta
                (255, 255, 0),    # Cyan
            ]
        
        margin_x = (self.screen_width - cols * target_size) // (cols + 1)
        margin_y = (self.screen_height - rows * target_size) // (rows + 1)
        
        idx = 0
        for row in range(rows):
            for col in range(cols):
                x = margin_x + col * (target_size + margin_x) + target_size // 2
                y = margin_y + row * (target_size + margin_y) + target_size // 2
                
                color = colors[idx % len(colors)]
                
                self.add_target(
                    target_id=f"target_{row}_{col}",
                    x=x,
                    y=y,
                    width=target_size,
                    height=target_size,
                    color=color,
                    shape='circle'
                )
                idx += 1
    
    def create_preference_test(
        self,
        left_color: Tuple[int, int, int] = (0, 255, 255),  # Yellow
        right_color: Tuple[int, int, int] = (255, 0, 0),    # Blue
        target_size: int = 300
    ):
        """
        Create a two-choice preference test layout.
        Good for assessing color preferences in CVI.
        """
        self.targets = []
        
        # Left target
        self.add_target(
            target_id="left",
            x=self.screen_width // 4,
            y=self.screen_height // 2,
            width=target_size,
            height=target_size,
            color=left_color,
            shape='circle'
        )
        
        # Right target
        self.add_target(
            target_id="right",
            x=3 * self.screen_width // 4,
            y=self.screen_height // 2,
            width=target_size,
            height=target_size,
            color=right_color,
            shape='circle'
        )
    
    def _check_gaze_on_target(self, screen_x: int, screen_y: int) -> Optional[str]:
        """Check if gaze point is on any target."""
        for target in self.targets:
            if target.shape == 'circle':
                # Check circular boundary
                dist = np.sqrt((screen_x - target.x)**2 + (screen_y - target.y)**2)
                if dist <= target.width // 2:
                    return target.id
            else:
                # Check rectangular boundary
                half_w = target.width // 2
                half_h = target.height // 2
                if (target.x - half_w <= screen_x <= target.x + half_w and
                    target.y - half_h <= screen_y <= target.y + half_h):
                    return target.id
        return None
    
    def _draw_targets(self, display: np.ndarray, highlight_id: Optional[str] = None):
        """Draw all targets on the display."""
        for target in self.targets:
            color = target.color
            thickness = -1  # Filled
            
            # Highlight if being gazed at
            is_highlighted = target.id == highlight_id
            
            if target.shape == 'circle':
                cv2.circle(
                    display,
                    (target.x, target.y),
                    target.width // 2,
                    color,
                    thickness
                )
                
                if is_highlighted:
                    # Draw highlight ring
                    cv2.circle(
                        display,
                        (target.x, target.y),
                        target.width // 2 + 10,
                        (255, 255, 255),
                        5
                    )
            else:
                half_w = target.width // 2
                half_h = target.height // 2
                cv2.rectangle(
                    display,
                    (target.x - half_w, target.y - half_h),
                    (target.x + half_w, target.y + half_h),
                    color,
                    thickness
                )
                
                if is_highlighted:
                    cv2.rectangle(
                        display,
                        (target.x - half_w - 10, target.y - half_h - 10),
                        (target.x + half_w + 10, target.y + half_h + 10),
                        (255, 255, 255),
                        5
                    )
    
    def _draw_dwell_indicator(
        self,
        display: np.ndarray,
        target: Target,
        progress: float
    ):
        """Draw a dwell progress indicator around target."""
        if progress <= 0:
            return
            
        # Draw arc showing dwell progress
        center = (target.x, target.y)
        radius = target.width // 2 + 20
        
        start_angle = -90
        end_angle = start_angle + int(360 * progress)
        
        cv2.ellipse(
            display,
            center,
            (radius, radius),
            0,
            start_angle,
            end_angle,
            (0, 255, 0),
            8
        )
    
    def _draw_gaze_cursor(self, display: np.ndarray, x: int, y: int):
        """Draw gaze cursor on display."""
        # Crosshair cursor
        size = 20
        cv2.line(display, (x - size, y), (x + size, y), (255, 255, 255), 2)
        cv2.line(display, (x, y - size), (x, y + size), (255, 255, 255), 2)
        cv2.circle(display, (x, y), 5, (0, 255, 0), -1)
    
    def run_session(
        self,
        duration: float = 60.0,
        show_gaze_cursor: bool = True,
        fullscreen: bool = True
    ) -> Dict:
        """
        Run an assessment session.
        
        Args:
            duration: Session duration in seconds
            show_gaze_cursor: Whether to show gaze position on screen
            fullscreen: Whether to use fullscreen display
            
        Returns:
            Session results dictionary
        """
        if not self.targets:
            print("No targets defined! Use create_grid_layout() or add_target() first.")
            return {}
        
        # Setup window
        window_name = "Visual Assessment"
        if fullscreen:
            cv2.namedWindow(window_name, cv2.WND_PROP_FULLSCREEN)
            cv2.setWindowProperty(window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
        else:
            cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
            cv2.resizeWindow(window_name, self.screen_width, self.screen_height)
        
        # Initialize session
        self.session_start = time.time()
        self.events = []
        self.selections = []
        self.current_target = None
        self.dwell_start = None
        
        print(f"\nStarting assessment session ({duration}s)")
        print("Press 'q' to quit early, 'r' to reset selection count")
        print("Arrow keys adjust gaze offset if needed (Up/Down for vertical)")
        
        try:
            while True:
                current_time = time.time()
                elapsed = current_time - self.session_start
                
                if elapsed >= duration:
                    break
                
                # Read camera frame
                ret, frame = self.tracker.cap.read()
                if not ret:
                    continue
                
                frame = cv2.flip(frame, 1)
                
                # Process gaze
                gaze_data, _ = self.tracker.process_frame(frame)
                
                # Create display
                display = np.full(
                    (self.screen_height, self.screen_width, 3),
                    self.background_color,
                    dtype=np.uint8
                )
                
                # Get screen gaze position
                screen_x, screen_y = 0, 0
                gazed_target = None
                
                # Use calibrated coordinates if available
                screen_point = self.get_calibrated_screen_point(gaze_data)
                if screen_point:
                    screen_x, screen_y = screen_point
                    gazed_target = self._check_gaze_on_target(screen_x, screen_y)
                
                # Handle dwell selection
                dwell_progress = 0
                if gazed_target:
                    if gazed_target != self.current_target:
                        self.current_target = gazed_target
                        self.dwell_start = current_time
                    elif self.dwell_start:
                        dwell_time = current_time - self.dwell_start
                        dwell_progress = min(1.0, dwell_time / self.dwell_threshold)
                        
                        if dwell_time >= self.dwell_threshold:
                            # Selection made!
                            self.selections.append(gazed_target)
                            
                            event = GazeEvent(
                                timestamp=elapsed,
                                target_id=gazed_target,
                                gaze_x=gaze_data.combined_gaze[0] if gaze_data.combined_gaze is not None else 0,
                                gaze_y=gaze_data.combined_gaze[1] if gaze_data.combined_gaze is not None else 0,
                                screen_x=screen_x,
                                screen_y=screen_y,
                                dwell_time=dwell_time,
                                selected=True
                            )
                            self.events.append(event)
                            
                            print(f"  Selection: {gazed_target} at {elapsed:.1f}s")
                            
                            # Reset dwell
                            self.dwell_start = current_time
                else:
                    self.current_target = None
                    self.dwell_start = None
                
                # Draw targets
                self._draw_targets(display, gazed_target)
                
                # Draw dwell indicator
                if gazed_target and dwell_progress > 0:
                    target = next(t for t in self.targets if t.id == gazed_target)
                    self._draw_dwell_indicator(display, target, dwell_progress)
                
                # Draw gaze cursor
                if show_gaze_cursor and gaze_data.screen_point:
                    self._draw_gaze_cursor(display, screen_x, screen_y)
                
                # Draw status bar
                remaining = duration - elapsed
                status = f"Time: {remaining:.1f}s | Selections: {len(self.selections)}"
                cv2.putText(
                    display, status,
                    (20, 40),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1, (150, 150, 150), 2
                )
                
                # Draw camera preview
                preview = cv2.resize(frame, (240, 180))
                display[self.screen_height - 200:self.screen_height - 20,
                       self.screen_width - 260:self.screen_width - 20] = preview
                
                cv2.imshow(window_name, display)
                
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    break
                elif key == ord('r'):
                    self.selections = []
                    print("Selection count reset")
                # Offset adjustments with arrow keys during assessment
                elif key == 82 or key == 0:  # Up arrow
                    off_y = self.tracker.offset_y - 0.05
                    self.tracker.set_offset(y=off_y)
                    print(f"Y Offset: {self.tracker.offset_y:+.2f} (gaze shifted UP)")
                elif key == 84 or key == 1:  # Down arrow
                    off_y = self.tracker.offset_y + 0.05
                    self.tracker.set_offset(y=off_y)
                    print(f"Y Offset: {self.tracker.offset_y:+.2f} (gaze shifted DOWN)")
                elif key == 81 or key == 2:  # Left arrow
                    off_x = self.tracker.offset_x - 0.05
                    self.tracker.set_offset(x=off_x)
                    print(f"X Offset: {self.tracker.offset_x:+.2f} (gaze shifted LEFT)")
                elif key == 83 or key == 3:  # Right arrow
                    off_x = self.tracker.offset_x + 0.05
                    self.tracker.set_offset(x=off_x)
                    print(f"X Offset: {self.tracker.offset_x:+.2f} (gaze shifted RIGHT)")
        
        finally:
            cv2.destroyWindow(window_name)
        
        # Generate results
        results = self._generate_results()
        return results
    
    def _generate_results(self) -> Dict:
        """Generate assessment results."""
        if not self.session_start:
            return {}
        
        session_duration = time.time() - self.session_start
        
        # Count selections per target
        selection_counts = {}
        for target in self.targets:
            selection_counts[target.id] = self.selections.count(target.id)
        
        # Calculate percentages
        total_selections = len(self.selections)
        selection_percentages = {}
        for target_id, count in selection_counts.items():
            pct = (count / total_selections * 100) if total_selections > 0 else 0
            selection_percentages[target_id] = round(pct, 1)
        
        results = {
            "session_date": datetime.now().isoformat(),
            "session_duration": round(session_duration, 1),
            "total_selections": total_selections,
            "selection_counts": selection_counts,
            "selection_percentages": selection_percentages,
            "targets": [asdict(t) for t in self.targets],
            "events": [asdict(e) for e in self.events],
            "dwell_threshold": self.dwell_threshold
        }
        
        return results
    
    def save_results(self, results: Dict, filename: str):
        """Save assessment results to JSON file."""
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"Results saved to {filename}")
    
    def print_summary(self, results: Dict):
        """Print a summary of assessment results."""
        print("\n" + "=" * 50)
        print("ASSESSMENT RESULTS")
        print("=" * 50)
        print(f"Duration: {results['session_duration']}s")
        print(f"Total selections: {results['total_selections']}")
        print("\nSelection breakdown:")
        for target_id, count in results['selection_counts'].items():
            pct = results['selection_percentages'][target_id]
            print(f"  {target_id}: {count} ({pct}%)")
        print("=" * 50)


def run_assessment_demo():
    """Run a demonstration of the visual assessment tool."""
    print("Visual Assessment Tool for CVI/AAC")
    print("=" * 50)
    
    # Initialize tracker with good sensitivity for assessment
    # Note: When using full calibration, sensitivity/offset are less important
    # because the calibration transform handles the mapping
    tracker = EyeGazeTracker(
        camera_id=0,
        screen_width=1920,
        screen_height=1080,
        sensitivity_x=2.5,
        sensitivity_y=3.0,
        offset_x=0.0,
        offset_y=0.3  # Default offset - calibration will override this
    )
    
    if not tracker.start_camera():
        print("Failed to start camera!")
        return
    
    # Create assessment tool
    assessment = VisualAssessmentTool(
        tracker,
        screen_width=1920,
        screen_height=1080,
        background_color=(0, 0, 0),  # Black background for CVI
        dwell_threshold=0.8  # 800ms dwell time
    )
    
    # Check for existing calibration
    calibration_exists = os.path.exists("gaze_calibration.npz")
    
    print("\nCalibration options:")
    print("1. Run full 9-point calibration (most accurate)")
    print("2. Run quick 5-point calibration")
    if calibration_exists:
        print("3. Load existing calibration (gaze_calibration.npz)")
        print("4. Skip calibration - use default settings")
    else:
        print("3. Skip calibration - use default settings")
    
    cal_choice = input("\nEnter choice: ").strip()
    
    if cal_choice == "1":
        # Full 9-point calibration using CalibrationTool
        print("\nRunning full 9-point calibration...")
        success = assessment.run_calibration(num_points=9)
        if success:
            print("Full calibration complete!")
        else:
            print("Calibration cancelled, using defaults")
    elif cal_choice == "2":
        # Quick 5-point calibration
        calibrator = QuickCalibration(tracker, 1920, 1080)
        offset_x, offset_y = calibrator.run(samples_per_point=20)
        tracker.set_offset(offset_x, offset_y)
        print(f"Applied offsets: X={offset_x:+.2f}, Y={offset_y:+.2f}")
    elif cal_choice == "3" and calibration_exists:
        # Load existing calibration
        if assessment.load_calibration("gaze_calibration.npz"):
            print("Using loaded calibration!")
        else:
            print("Failed to load calibration, using defaults")
    else:
        print("Using default settings")
    
    print("\nSelect assessment type:")
    print("1. 2x2 Grid (4 choices)")
    print("2. 3x3 Grid (9 choices)")
    print("3. Two-choice preference test")
    
    choice = input("\nEnter choice (1-3): ").strip()
    
    if choice == "1":
        assessment.create_grid_layout(rows=2, cols=2, target_size=250)
    elif choice == "2":
        assessment.create_grid_layout(rows=3, cols=3, target_size=150)
    else:
        assessment.create_preference_test(
            left_color=(0, 255, 255),   # Yellow
            right_color=(255, 0, 0)      # Blue
        )
    
    # Run session
    results = assessment.run_session(
        duration=30.0,
        show_gaze_cursor=True,
        fullscreen=False  # Set True for actual assessments
    )
    
    if results:
        assessment.print_summary(results)
        
        # Add calibration info to results
        results['calibration'] = {
            'offset_x': tracker.offset_x,
            'offset_y': tracker.offset_y,
            'sensitivity_x': tracker.sensitivity_x,
            'sensitivity_y': tracker.sensitivity_y,
            'used_full_calibration': assessment.calibrator is not None
        }
        
        # Save results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"assessment_results_{timestamp}.json"
        assessment.save_results(results, filename)
    
    tracker.stop_camera()


def quick_vertical_calibration(tracker: EyeGazeTracker) -> float:
    """
    Super quick vertical-only calibration.
    Just measures where 'top' is detected and computes offset.
    """
    cv2.namedWindow("Quick Cal", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("Quick Cal", 800, 600)
    
    samples = []
    collecting = False
    
    print("Look at the TOP of your screen and press SPACE to calibrate...")
    
    while len(samples) < 15:
        ret, frame = tracker.cap.read()
        if not ret:
            continue
        
        frame = cv2.flip(frame, 1)
        gaze_data, annotated = tracker.process_frame(frame)
        
        # Draw instruction
        cv2.putText(annotated, "Look at TOP of screen, press SPACE", 
                   (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        
        if collecting:
            cv2.putText(annotated, f"Recording: {len(samples)}/15", 
                       (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        cv2.imshow("Quick Cal", annotated)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord(' '):
            collecting = True
        elif key == 27:  # ESC
            break
        
        if collecting and gaze_data.combined_gaze is not None:
            samples.append(gaze_data.combined_gaze[1])
    
    cv2.destroyWindow("Quick Cal")
    
    if not samples:
        return tracker.offset_y
    
    # When looking at top, gaze_y should be -1
    # Measure what it actually is and compute offset
    measured_y = np.mean(samples)
    expected_y = -0.8  # Top of screen (with some margin)
    
    error_y = expected_y - measured_y
    new_offset_y = tracker.offset_y + error_y
    new_offset_y = np.clip(new_offset_y, -1.0, 1.0)
    
    print(f"Measured top gaze: {measured_y:+.2f}, expected: {expected_y:+.2f}")
    print(f"Computed Y offset: {new_offset_y:+.2f}")
    
    return new_offset_y


if __name__ == "__main__":
    run_assessment_demo()
