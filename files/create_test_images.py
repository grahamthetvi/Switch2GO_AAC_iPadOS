import cv2
import numpy as np
import qrcode
from PIL import Image


def create_test_qr_images():
    """
    Creates test images with QR codes in different corners.
    """
    # Create QR code
    qr = qrcode.QRCode(version=1, box_size=10, border=2)
    qr.add_data("Hello")
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white")
    
    # Convert to numpy array
    qr_array = np.array(qr_img.convert('RGB'))
    qr_height, qr_width = qr_array.shape[:2]
    
    # Create base image (800x800 white background)
    img_size = 800
    positions = {
        'top-left': (50, 50),
        'top-right': (img_size - qr_width - 50, 50),
        'bottom-left': (50, img_size - qr_height - 50),
        'bottom-right': (img_size - qr_width - 50, img_size - qr_height - 50)
    }
    
    for pos_name, (x, y) in positions.items():
        # Create white background
        img = np.ones((img_size, img_size, 3), dtype=np.uint8) * 255
        
        # Place QR code
        img[y:y+qr_height, x:x+qr_width] = qr_array
        
        # Save image
        filename = f"test_qr_{pos_name}.png"
        cv2.imwrite(filename, img)
        print(f"Created {filename}")


if __name__ == "__main__":
    print("Installing qrcode package if needed...")
    import subprocess
    subprocess.run(["pip", "install", "qrcode[pil]", "--break-system-packages", "-q"])
    
    create_test_qr_images()
    print("\nTest images created! You can now run:")
    print("python qr_corner_detector.py test_qr_top-left.png")
