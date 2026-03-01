#!/usr/bin/env python3
"""
Export L2CS-Net to ONNX format for Android deployment.

This script downloads the L2CS-Net pretrained weights and exports them to ONNX format
that can be used with ONNX Runtime on Android.

Usage:
    pip install torch torchvision onnx l2cs-net
    python export_l2cs_to_onnx.py

The output model will be saved to: app/src/main/assets/l2cs_net.onnx
"""

import torch
import torch.nn as nn
import os
from pathlib import Path

# Try to import from l2cs package
try:
    from l2cs import Pipeline
    from l2cs.model import L2CS
except ImportError:
    print("L2CS-Net not installed. Installing...")
    os.system("pip install git+https://github.com/edavalosanaya/L2CS-Net.git@main")
    from l2cs import Pipeline
    from l2cs.model import L2CS


def download_weights():
    """Download pretrained weights if not present."""
    import urllib.request
    
    weights_dir = Path("models")
    weights_dir.mkdir(exist_ok=True)
    
    weights_path = weights_dir / "L2CSNet_gaze360.pkl"
    
    if not weights_path.exists():
        print("Downloading L2CS-Net weights...")
        # The weights URL from the official repository
        url = "https://github.com/Ahmednull/L2CS-Net/releases/download/v1.0/L2CSNet_gaze360.pkl"
        try:
            urllib.request.urlretrieve(url, weights_path)
            print(f"Downloaded weights to {weights_path}")
        except Exception as e:
            print(f"Error downloading weights: {e}")
            print("Please download manually from: https://github.com/Ahmednull/L2CS-Net")
            return None
    
    return weights_path


def export_to_onnx(weights_path: Path, output_path: Path):
    """Export L2CS-Net model to ONNX format."""
    
    print(f"Loading model from {weights_path}...")
    
    # Create model with ResNet50 backbone (same as pretrained)
    model = L2CS(arch='ResNet50', num_bins=90)
    
    # Load pretrained weights
    checkpoint = torch.load(weights_path, map_location='cpu')
    
    # Handle different checkpoint formats
    if 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)
    
    model.eval()
    
    # Create dummy input (batch_size=1, channels=3, height=224, width=224)
    dummy_input = torch.randn(1, 3, 224, 224)
    
    print(f"Exporting to ONNX...")
    
    # Export to ONNX
    torch.onnx.export(
        model,
        dummy_input,
        str(output_path),
        export_params=True,
        opset_version=12,
        do_constant_folding=True,
        input_names=['input'],
        output_names=['pitch', 'yaw'],
        dynamic_axes={
            'input': {0: 'batch_size'},
            'pitch': {0: 'batch_size'},
            'yaw': {0: 'batch_size'}
        }
    )
    
    print(f"Model exported to {output_path}")
    
    # Verify the model
    try:
        import onnx
        onnx_model = onnx.load(str(output_path))
        onnx.checker.check_model(onnx_model)
        print("ONNX model verification passed!")
    except ImportError:
        print("Install 'onnx' package to verify the model: pip install onnx")
    
    # Print model info
    file_size = output_path.stat().st_size / (1024 * 1024)
    print(f"Model size: {file_size:.2f} MB")


def main():
    # Get script directory
    script_dir = Path(__file__).parent.parent
    assets_dir = script_dir / "app" / "src" / "main" / "assets"
    
    # Ensure output directory exists
    assets_dir.mkdir(parents=True, exist_ok=True)
    
    output_path = assets_dir / "l2cs_net.onnx"
    
    # Download weights
    weights_path = download_weights()
    if weights_path is None:
        return
    
    # Export to ONNX
    export_to_onnx(weights_path, output_path)
    
    print("\n" + "="*60)
    print("SETUP COMPLETE!")
    print("="*60)
    print(f"\nThe L2CS-Net model has been exported to:")
    print(f"  {output_path}")
    print("\nYou also need the MediaPipe face detection model.")
    print("Download 'face_detection_short_range.tflite' from:")
    print("  https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite")
    print(f"\nSave it to:")
    print(f"  {assets_dir / 'face_detection_short_range.tflite'}")
    print("\nAlternatively, the app will fall back to using face_landmarker.task")
    print("if the short range model is not available.")


if __name__ == "__main__":
    main()

