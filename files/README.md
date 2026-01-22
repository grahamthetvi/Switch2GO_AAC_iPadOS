# QR Code Corner Position Detector

A reliable Python script that reads QR codes and detects which corner of the image they're located in (top-left, top-right, bottom-left, or bottom-right).

## Features

- **Reliable QR detection** using OpenCV's built-in QR code detector
- **Corner position detection** - automatically determines which quadrant the QR code is in
- **Two modes**: Image file analysis or real-time camera detection
- **Visual feedback** in camera mode with quadrant lines and detected position overlay

## Installation

1. Install required packages:
```bash
pip install -r requirements.txt
```

Or manually:
```bash
pip install opencv-python numpy
```

## Usage

### Mode 1: Analyze an Image File

```bash
python qr_corner_detector.py path/to/your/image.png
```

Output:
```
Decoded Text: Hello World
Position: top-right
```

### Mode 2: Real-time Camera Detection

```bash
python qr_corner_detector.py
```

This will:
- Open your default camera
- Display a live feed with quadrant lines
- Show the decoded text and corner position when a QR code is detected
- Press 'q' to quit

## How It Works

1. **Detection**: Uses OpenCV's `QRCodeDetector()` which is highly reliable
2. **Position Calculation**: 
   - Finds the 4 corner points of the QR code
   - Calculates the center point
   - Compares center to image midpoints to determine quadrant
3. **Decoding**: Extracts the text/data from the QR code

## Testing

To create test images with QR codes in different corners:

```bash
python create_test_images.py
```

This creates 4 test images:
- `test_qr_top-left.png`
- `test_qr_top-right.png`
- `test_qr_bottom-left.png`
- `test_qr_bottom-right.png`

Test them:
```bash
python qr_corner_detector.py test_qr_top-left.png
python qr_corner_detector.py test_qr_top-right.png
```

## Using in Your Own Code

```python
from qr_corner_detector import detect_qr_code_and_position

text, position = detect_qr_code_and_position("image.png")

if text:
    print(f"Found: {text} in {position}")
else:
    print("No QR code detected")
```

## Requirements

- Python 3.6+
- OpenCV (opencv-python)
- NumPy

## Why This Works Reliably

- **OpenCV's QR detector** is industrial-strength and handles various lighting conditions, angles, and QR code sizes
- **Robust positioning** using geometric center calculation rather than relying on single points
- **Works with any QR code content** - words, URLs, numbers, etc.
- **Handles rotated QR codes** - position is based on center point, not orientation

## Troubleshooting

**QR code not detected:**
- Ensure good lighting
- QR code should be clearly visible and not too small
- Try holding steadier or adjusting distance

**Wrong position detected:**
- The script divides the image into 4 equal quadrants
- Position is based on where the QR code's CENTER point falls
- A QR code near the middle lines might be close to the boundary

## License

Free to use and modify as needed.
