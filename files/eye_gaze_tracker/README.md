# Eye Gaze Tracker

Implementation of **MediaPipe Iris + Kalman Filters** for robust eye gaze tracking, based on the research paper by Ramesh V et al. (2025).

## Overview

This system combines Google's MediaPipe Iris for real-time iris detection with Kalman Filters for noise reduction and predictive smoothing. It's designed to work with standard RGB webcams and provides:

- Real-time gaze tracking at 30+ FPS
- Kalman filter smoothing for stable gaze estimation
- Screen coordinate mapping with optional calibration
- Visual assessment tools for CVI screening and AAC applications
- Low latency (~25-30ms per frame)

## Installation

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

Or install individually:

```bash
pip install opencv-python numpy mediapipe
```

### 2. Verify Camera Access

Make sure you have a webcam connected. The system works best with:
- 720p or higher resolution
- 30+ FPS capability
- Good lighting (though Kalman filtering helps with low light)

## Quick Start

### Basic Gaze Tracking Demo

```bash
python gaze_tracker.py
```

This opens a window showing:
- Live camera feed with iris detection
- Gaze direction indicator (top-right corner)
- FPS and latency stats
- Screen coordinate estimation

**Controls:**
- `q` - Quit
- `r` - Reset Kalman filters
- `c` - Save screenshot
- `+/-` - Adjust sensitivity
- `Arrow keys` - Adjust gaze offset
- `0` - Reset offset

### Calibration (Recommended for Accuracy)

```bash
python calibration.py
```

This runs a 9-point calibration procedure:
1. Look at each dot as it appears
2. Press SPACE to record your gaze at each point
3. The system computes a transformation matrix for accurate screen mapping

**Calibration data is saved to `gaze_calibration.npz`** and can be loaded by the assessment tool!

### Visual Assessment Tool (For CVI/AAC)

```bash
python visual_assessment.py
```

**NEW: The assessment tool now integrates with calibration!**

When you run the assessment, you'll be asked:
1. **Run full 9-point calibration** - Most accurate, recommended
2. **Run quick 5-point calibration** - Faster but less precise
3. **Load existing calibration** - Uses saved `gaze_calibration.npz` from previous session
4. **Skip calibration** - Use default settings

**Workflow:**
1. Run `calibration.py` once to create `gaze_calibration.npz`
2. Run `visual_assessment.py` and choose "Load existing calibration"
3. The assessment will use your calibrated gaze mapping!

## How Calibration Works

Without calibration, the system uses simple linear mapping from gaze to screen coordinates. This works okay but has two problems:

1. **Offset bias** - Your detected gaze might be consistently shifted (e.g., always reads "up" even when looking at center)
2. **Scale mismatch** - The range of detected gaze might not match the screen (e.g., you have to look way to the side to reach screen edges)

The 9-point calibration solves both by:
1. Collecting gaze samples at 9 known screen positions
2. Computing an **affine transformation** that maps your actual gaze patterns to correct screen coordinates
3. Saving this transform to `gaze_calibration.npz`

**Your calibration data from `calibration.py` shows:**
- Top row: gaze_y ≈ -0.45 (should be near -1)
- Middle row: gaze_y ≈ -0.25 (should be near 0)
- Bottom row: gaze_y ≈ +0.10 (should be near +1)

The calibration transform corrects this automatically!

## Usage in Your Own Code

### Basic Integration

```python
from gaze_tracker import EyeGazeTracker

# Initialize tracker
tracker = EyeGazeTracker(
    camera_id=0,
    screen_width=1920,
    screen_height=1080,
    smoothing_factor=0.4  # Higher = more responsive, Lower = smoother
)

# Start camera
tracker.start_camera(width=1280, height=720, fps=30)

# Process frames
while True:
    ret, frame = tracker.cap.read()
    frame = cv2.flip(frame, 1)  # Mirror for intuitive interaction
    
    gaze_data, annotated_frame = tracker.process_frame(frame)
    
    if gaze_data.screen_point:
        x, y = gaze_data.screen_point
        print(f"Looking at: ({x}, {y})")
    
    cv2.imshow("Gaze", annotated_frame)
    if cv2.waitKey(1) == ord('q'):
        break

tracker.stop_camera()
```

### Adjusting Kalman Filter Parameters

```python
tracker = EyeGazeTracker(
    process_noise=1e-4,      # Lower = smoother but more lag
    measurement_noise=1e-2,  # Higher = trust predictions more
    smoothing_factor=0.3     # Additional exponential smoothing
)
```

**Tuning guide:**
- For jittery tracking: Lower `process_noise` or `smoothing_factor`
- For laggy tracking: Higher values, or reset filters more often
- For rapid movements: Higher `process_noise`

### Custom Visual Assessment

```python
from gaze_tracker import EyeGazeTracker
from visual_assessment import VisualAssessmentTool

tracker = EyeGazeTracker(camera_id=0)
tracker.start_camera()

assessment = VisualAssessmentTool(
    tracker,
    background_color=(0, 0, 0),  # Black - good for CVI
    dwell_threshold=1.0  # 1 second to select
)

# CVI-friendly high contrast colors
assessment.create_grid_layout(
    rows=2,
    cols=2,
    target_size=300,
    colors=[
        (0, 255, 255),   # Yellow
        (255, 0, 0),     # Blue
        (0, 0, 255),     # Red
        (0, 255, 0),     # Green
    ]
)

results = assessment.run_session(duration=60)
assessment.print_summary(results)
assessment.save_results(results, "session.json")
```

## Performance Expectations

Based on the research paper and this implementation:

| Condition | Expected Accuracy | Latency |
|-----------|------------------|---------|
| Good lighting, still head | 95-97% | 25ms |
| Low light | 90-92% | 28ms |
| With glasses | 88-90% | 30ms |
| Rapid head movement | 85-88% | 32ms |

## Tips for Best Results

### Lighting
- Avoid backlighting (light behind you)
- Even, diffused front lighting works best
- The Kalman filter helps compensate for low light

### Positioning
- Face camera directly
- ~40-60cm from camera
- Keep head relatively still (small movements are filtered)

### For CVI Assessment
- Use black backgrounds
- Use large, high-contrast targets (yellow/red work well)
- Start with longer dwell times (1-2 seconds)
- Reduce number of choices initially

## File Structure

```
eye_gaze_tracker/
├── gaze_tracker.py      # Core tracking implementation
├── calibration.py       # Screen calibration tool
├── visual_assessment.py # CVI/AAC assessment tool
├── requirements.txt     # Python dependencies
└── README.md           # This file
```

## Differences from the Paper

This implementation follows the paper's methodology but includes some practical additions:

1. **Exponential smoothing layer** - Additional smoothing on top of Kalman filtering
2. **Blink detection** - Pauses tracking during blinks
3. **Visual assessment module** - Not in original paper, added for practical CVI/AAC use
4. **Configurable parameters** - Easy tuning of filter parameters

## Troubleshooting

**"No face detected"**
- Check lighting
- Move closer to camera
- Ensure face is clearly visible

**Jittery gaze cursor**
- Reduce `smoothing_factor`
- Lower `process_noise` in Kalman filter
- Check for reflections on glasses

**High latency**
- Lower camera resolution
- Close other camera applications
- Check CPU usage

**Calibration fails**
- Ensure good lighting
- Keep head very still during calibration
- Try fewer calibration points (5 instead of 9)

## References

- Ramesh V et al. (2025). "MediaPipe Iris and Kalman Filter for Robust Eye Gaze Tracking"
- Google MediaPipe: https://github.com/google/mediapipe
- MediaPipe Iris documentation: https://google.github.io/mediapipe/solutions/iris

## License

This implementation is provided for educational and research purposes. The underlying MediaPipe library is subject to Apache 2.0 license.
