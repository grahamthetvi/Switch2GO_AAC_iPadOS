import cv2
import numpy as np
from typing import Tuple, Optional


def detect_qr_code_and_position(image_path: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Detects QR code in an image, reads its content, and determines its corner position.
    
    Args:
        image_path: Path to the image file
        
    Returns:
        Tuple of (decoded_text, corner_position)
        corner_position can be: 'top-left', 'top-right', 'bottom-left', 'bottom-right', or None
    """
    # Read the image
    img = cv2.imread(image_path)
    
    if img is None:
        print(f"Error: Could not read image from {image_path}")
        return None, None
    
    # Get image dimensions
    height, width = img.shape[:2]
    
    # Initialize QR code detector
    qr_detector = cv2.QRCodeDetector()
    
    # Detect and decode QR code
    decoded_text, points, _ = qr_detector.detectAndDecode(img)
    
    if decoded_text and points is not None:
        # Calculate the center of the QR code
        # points is a numpy array of shape (1, 4, 2) containing the 4 corner points
        points = points[0]  # Get the first (and only) QR code's points
        
        # Calculate center point
        center_x = np.mean(points[:, 0])
        center_y = np.mean(points[:, 1])
        
        # Determine which quadrant the center is in
        mid_x = width / 2
        mid_y = height / 2
        
        if center_x < mid_x and center_y < mid_y:
            position = "top-left"
        elif center_x >= mid_x and center_y < mid_y:
            position = "top-right"
        elif center_x < mid_x and center_y >= mid_y:
            position = "bottom-left"
        else:
            position = "bottom-right"
        
        return decoded_text, position
    else:
        print("No QR code detected in the image")
        return None, None


def detect_qr_from_camera(camera_index: int = 0) -> None:
    """
    Real-time QR code detection from camera feed.
    
    Args:
        camera_index: Camera device index (default: 0)
    """
    cap = cv2.VideoCapture(camera_index)
    qr_detector = cv2.QRCodeDetector()
    
    print("Press 'q' to quit")
    
    while True:
        ret, frame = cap.read()
        
        if not ret:
            print("Failed to grab frame")
            break
        
        height, width = frame.shape[:2]
        mid_x, mid_y = width // 2, height // 2
        
        # Draw quadrant lines for visualization
        cv2.line(frame, (mid_x, 0), (mid_x, height), (0, 255, 0), 1)
        cv2.line(frame, (0, mid_y), (width, mid_y), (0, 255, 0), 1)
        
        # Detect QR code
        decoded_text, points, _ = qr_detector.detectAndDecode(frame)
        
        if decoded_text and points is not None:
            # Draw QR code boundary
            points = points[0].astype(int)
            cv2.polylines(frame, [points], True, (0, 255, 0), 3)
            
            # Calculate center
            center_x = int(np.mean(points[:, 0]))
            center_y = int(np.mean(points[:, 1]))
            
            # Draw center point
            cv2.circle(frame, (center_x, center_y), 5, (0, 0, 255), -1)
            
            # Determine position
            if center_x < mid_x and center_y < mid_y:
                position = "top-left"
            elif center_x >= mid_x and center_y < mid_y:
                position = "top-right"
            elif center_x < mid_x and center_y >= mid_y:
                position = "bottom-left"
            else:
                position = "bottom-right"
            
            # Display text and position
            cv2.putText(frame, f"Text: {decoded_text}", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(frame, f"Position: {position}", (10, 60),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        
        cv2.imshow('QR Code Corner Detection', frame)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        # Image file mode
        image_path = sys.argv[1]
        text, position = detect_qr_code_and_position(image_path)
        
        if text:
            print(f"Decoded Text: {text}")
            print(f"Position: {position}")
        else:
            print("No QR code found or could not be decoded")
    else:
        # Camera mode
        print("No image file provided. Starting camera mode...")
        print("Show a QR code to the camera to detect its position.")
        detect_qr_from_camera()
