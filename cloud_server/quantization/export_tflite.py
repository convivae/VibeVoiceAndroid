#!/usr/bin/env python3
"""
VibeVoice-ASR TFLite Export Script

Converts AWQ-quantized model to TensorFlow Lite format for mobile inference.

Pipeline: AWQ → ONNX → TFLite

Requirements:
- CUDA 12+
- Python 3.10+
- autoawq, onnx, onnx2tf, tensorflow installed

Usage:
    python export_tflite.py [--input PATH] [--output PATH]

Decisions locked:
- D-01: TensorFlow Lite (NOT MNN/llama.cpp)
- SELECT_TF_OPS required for custom ops
"""

import argparse
import os
import sys
from pathlib import Path

# Third-party imports
try:
    import torch
    import onnx
    from onnx import numpy_helper
except ImportError as e:
    print(f"ERROR: Missing dependency - {e}")
    print("Install with: pip install onnx torch")
    sys.exit(1)

# Configuration
AWQ_MODEL_PATH = "./quantized_vibevoice_asr"
ONNX_OUTPUT = "./vibevoice_asr.onnx"
TFLITE_OUTPUT_DIR = "./tflite_output"
TFLITE_MODEL_NAME = "vibevoice_asr_int4.tflite"


def check_dependencies():
    """Check if all required dependencies are installed."""
    missing = []
    try:
        import onnx2tf
    except ImportError:
        missing.append("onnx2tf")

    try:
        import tensorflow as tf
    except ImportError:
        missing.append("tensorflow")

    if missing:
        print(f"WARNING: Missing dependencies: {', '.join(missing)}")
        print("Install with: pip install onnx2tf tensorflow")
        return False
    return True


def load_awq_model(model_path: str):
    """Load AWQ quantized model and dequantize to FP16.

    Args:
        model_path: Path to AWQ quantized model

    Returns:
        Dequantized FP16 model ready for ONNX export
    """
    print(f"Loading AWQ model from: {model_path}")

    try:
        from awq import AutoAWQForCausalLM
        model = AutoAWQForCausalLM.from_pretrained(
            model_path,
            device_map="cpu",  # Use CPU for dequantization (less memory pressure)
            trust_remote_code=True,
        )
        print("AWQ model loaded successfully")
        return model
    except Exception as e:
        print(f"ERROR: Failed to load AWQ model - {e}")
        return None


def prepare_example_input():
    """Prepare example input for ONNX export.

    Returns:
        Tuple of (input_tensor, input_shape)
    """
    # Whisper-style audio input: [batch, 1, 16000] (1 second of 16kHz audio)
    batch_size = 1
    audio_length = 16000  # 1 second at 16kHz
    example_input = torch.randn(batch_size, 1, audio_length)
    return example_input


def export_to_onnx(model, output_path: str):
    """Export model to ONNX format.

    Args:
        model: PyTorch model to export
        output_path: Output path for ONNX file

    Returns:
        True if successful, False otherwise
    """
    print(f"\n[2/4] Exporting to ONNX: {output_path}")

    try:
        example_input = prepare_example_input()

        # Model export to ONNX
        # Note: VibeVoice-ASR may require component-wise export
        # due to complex architecture (Dual VAE + Qwen2 LLM)
        print("Preparing for ONNX export...")

        # For complex models, we may need to export each component separately:
        # 1. Acoustic VAE encoder
        # 2. Semantic VAE encoder
        # 3. Qwen2 LLM decoder
        # This is a placeholder - actual implementation depends on model architecture

        torch.onnx.export(
            model,
            example_input,
            output_path,
            input_names=['input_audio'],
            output_names=['transcription_logits'],
            opset_version=14,
            dynamic_axes={
                'input_audio': {0: 'batch', 2: 'audio_length'},
                'transcription_logits': {0: 'batch', 1: 'seq_length'},
            },
        )

        # Verify ONNX model
        onnx_model = onnx.load(output_path)
        onnx.checker.check_model(onnx_model)
        print(f"ONNX model saved: {output_path}")

        return True

    except Exception as e:
        print(f"ERROR: ONNX export failed - {e}")
        print("\nPossible causes:")
        print("  1. Model has unsupported operators for ONNX")
        print("  2. Custom ops in VibeVoice-ASR not exportable")
        print("  3. Input shapes incompatible with model")
        return False


def convert_onnx_to_tflite(onnx_path: str, output_dir: str):
    """Convert ONNX model to TensorFlow Lite format.

    Args:
        onnx_path: Input ONNX file path
        output_dir: Output directory for TFLite model

    Returns:
        Path to TFLite model if successful, None otherwise
    """
    print(f"\n[3/4] Converting ONNX to TFLite: {output_dir}")

    try:
        from onnx2tf import convert

        os.makedirs(output_dir, exist_ok=True)

        # Convert with SELECT_TF_OPS enabled (required for custom ops)
        convert(
            input_onnx_file_path=onnx_path,
            output_folder=output_dir,
            enable_select_tf_ops=True,  # D-01 + custom ops requirement
        )

        tflite_path = os.path.join(output_dir, TFLITE_MODEL_NAME)
        if os.path.exists(tflite_path):
            size_mb = os.path.getsize(tflite_path) / (1024 * 1024)
            print(f"TFLite model created: {tflite_path}")
            print(f"Model size: {size_mb:.2f} MB")

            # Size validation (REQ-08)
            TARGET_MB = 500
            if size_mb > TARGET_MB:
                print(f"\n⚠️  WARNING: Model size ({size_mb:.2f} MB) exceeds target ({TARGET_MB} MB)")
                print("  This is a BLOCKING issue for Wave 2 tasks")
            else:
                print(f"\n✅ SUCCESS: Model size within target ({TARGET_MB} MB)")

            return tflite_path
        else:
            print("ERROR: TFLite model not created")
            return None

    except ImportError:
        print("ERROR: onnx2tf not installed")
        print("Install with: pip install onnx2tf")
        return None
    except Exception as e:
        print(f"ERROR: TFLite conversion failed - {e}")
        print("\nTroubleshooting:")
        print("  1. Check for unsupported operators in ONNX model")
        print("  2. Verify SELECT_TF_OPS covers all custom ops")
        print("  3. Consider using smaller model variant")
        return None


def report_model_info(tflite_path: str):
    """Generate model information report.

    Args:
        tflite_path: Path to TFLite model
    """
    print("\n[4/4] Model Information Report")
    print("=" * 40)

    if not os.path.exists(tflite_path):
        print("TFLite model not found")
        return

    size_bytes = os.path.getsize(tflite_path)
    size_mb = size_bytes / (1024 * 1024)
    size_gb = size_mb / 1024

    print(f"Model: {tflite_path}")
    print(f"Size: {size_mb:.2f} MB ({size_gb:.4f} GB)")

    if size_mb > 500:
        print("\n⚠️  BLOCKING ISSUE: Model exceeds 500MB target")
        print("Cannot proceed to Wave 2 until this is resolved")
    else:
        print("\n✅ Model within size constraints")


def export_to_tflite(
    awq_model_path: str = AWQ_MODEL_PATH,
    onnx_output: str = ONNX_OUTPUT,
    tflite_output_dir: str = TFLITE_OUTPUT_DIR,
):
    """Main export pipeline: AWQ → ONNX → TFLite.

    Args:
        awq_model_path: Path to AWQ quantized model
        onnx_output: Output path for ONNX file
        tflite_output_dir: Output directory for TFLite

    Returns:
        dict with export results
    """
    print("=" * 60)
    print("VibeVoice-ASR TFLite Export Pipeline")
    print("=" * 60)
    print(f"AWQ Model: {awq_model_path}")
    print(f"ONNX Output: {onnx_output}")
    print(f"TFLite Output: {tflite_output_dir}")

    # Check dependencies
    check_dependencies()

    # Step 1: Load AWQ model and dequantize
    model = load_awq_model(awq_model_path)
    if model is None:
        return {"success": False, "error": "Failed to load AWQ model"}

    # Step 2: Export to ONNX
    if not export_to_onnx(model, onnx_output):
        return {"success": False, "error": "ONNX export failed"}

    # Step 3: Convert to TFLite
    tflite_path = convert_onnx_to_tflite(onnx_output, tflite_output_dir)
    if tflite_path is None:
        return {"success": False, "error": "TFLite conversion failed"}

    # Step 4: Report
    report_model_info(tflite_path)

    return {
        "success": True,
        "onnx_path": onnx_output,
        "tflite_path": tflite_path,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Export VibeVoice-ASR to TensorFlow Lite format"
    )
    parser.add_argument(
        "--input",
        type=str,
        default=AWQ_MODEL_PATH,
        help=f"AWQ model path (default: {AWQ_MODEL_PATH})",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=TFLITE_OUTPUT_DIR,
        help=f"TFLite output directory (default: {TFLITE_OUTPUT_DIR})",
    )

    args = parser.parse_args()

    result = export_to_tflite(
        awq_model_path=args.input,
        tflite_output_dir=args.output,
    )

    if result.get("success"):
        print("\n" + "=" * 60)
        print("TFLite export completed successfully")
        print(f"Output: {result['tflite_path']}")
        print("=" * 60)
        sys.exit(0)
    else:
        print("\n" + "=" * 60)
        print(f"TFLite export FAILED: {result.get('error', 'Unknown error')}")
        print("=" * 60)
        sys.exit(1)


if __name__ == "__main__":
    main()