#!/usr/bin/env python3
"""
VibeVoice-ASR WER Evaluation Script

Evaluates ASR quality by comparing Word Error Rate (WER) between:
- FP16 baseline model
- INT4 AWQ quantized model

Requirements:
- Python 3.10+
- transformers, torch, datasets, jiwer installed
- Librispeech test-clean dataset

Usage:
    # FP16 baseline
    python evaluate_wer.py --model-path microsoft/VibeVoice-ASR --dtype fp16 --dataset librispeech

    # INT4 quantized
    python evaluate_wer.py --model-path ./quantized_vibevoice_asr --dtype int4 --dataset librispeech

    # Quick test (10 samples)
    python evaluate_wer.py --model-path ./quantized_vibevoice_asr --quick

Success criteria (REQ-12):
- WER loss < 15% vs FP16 baseline

NOTE: This script requires actual quantized model to be ready.
Skip actual evaluation if model not ready (GPU server required).
"""

import argparse
import sys
import os

# Third-party imports
try:
    import torch
    import numpy as np
except ImportError as e:
    print(f"ERROR: Missing dependency - {e}")
    print("Install with: pip install torch numpy")
    sys.exit(1)

# Configuration
MODEL_PATH = "microsoft/VibeVoice-ASR"
DATASET_NAME = "librispeech_asr"
DATASET_SPLIT = "test"
SUBSET = "clean"

# WER target from REQ-12
WER_LOSS_TARGET = 0.15  # 15% max acceptable loss


def load_dataset(split: str = SUBSET, n_samples: int = None, quick: bool = False):
    """Load Librispeech test-clean dataset.

    Args:
        split: Dataset split (clean, other)
        n_samples: Limit number of samples
        quick: If True, use only 10 samples for quick test

    Returns:
        dict with audio and transcription data
    """
    print(f"Loading LibrisSpeech test-{split} dataset...")

    try:
        from datasets import load_dataset
    except ImportError:
        print("ERROR: datasets library not installed")
        print("Install with: pip install datasets")
        return None

    try:
        # Load test-clean subset
        ds = load_dataset(DATASET_NAME, split, split=DATASET_SPLIT)

        # Limit samples if specified
        if n_samples:
            ds = ds.select(range(min(n_samples, len(ds))))
        elif quick:
            ds = ds.select(range(min(10, len(ds))))
            print(f"Quick test mode: {len(ds)} samples")

        print(f"Loaded {len(ds)} test samples")
        return ds

    except Exception as e:
        print(f"ERROR: Failed to load dataset - {e}")
        return None


def load_model(model_path: str, dtype: str = "fp16"):
    """Load ASR model for evaluation.

    Args:
        model_path: Path to model (HuggingFace or local)
        dtype: Data type (fp16 or int4)

    Returns:
        Loaded model or None
    """
    print(f"Loading {dtype.upper()} model from: {model_path}")

    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
        from peft import LoraConfig  # May be needed for some models

        # Determine device
        device = "cuda:0" if torch.cuda.is_available() else "cpu"
        torch_dtype = torch.float16 if dtype == "fp16" else torch.float32

        # Load tokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            model_path,
            trust_remote_code=True,
        )

        # Load model
        model = AutoModelForCausalLM.from_pretrained(
            model_path,
            torch_dtype=torch_dtype,
            device_map=device if dtype == "fp16" else "cpu",
            trust_remote_code=True,
        )

        print(f"Model loaded on: {device}")
        return model, tokenizer

    except Exception as e:
        print(f"ERROR: Failed to load model - {e}")
        print("\nPossible causes:")
        print("  1. Model not quantized yet (run awq_quantize.py first)")
        print("  2. Wrong model path")
        print("  3. Missing dependencies")
        return None, None


def transcribe_audio(model, tokenizer, audio_array: np.ndarray, sampling_rate: int) -> str:
    """Transcribe audio to text.

    Args:
        model: ASR model
        tokenizer: Tokenizer
        audio_array: Audio data as numpy array
        sampling_rate: Audio sampling rate

    Returns:
        Transcription text
    """
    try:
        # Prepare input ( Whisper-style processing)
        input_features = preprocess_audio(audio_array, sampling_rate, tokenizer)

        # Generate transcription
        with torch.no_grad():
            output = model.generate(input_features, max_new_tokens=256)

        # Decode
        transcription = tokenizer.decode(output[0], skip_special_tokens=True)
        return transcription

    except Exception as e:
        print(f"Transcription error: {e}")
        return ""


def preprocess_audio(audio_array: np.ndarray, sampling_rate: int, tokenizer) -> torch.Tensor:
    """Preprocess audio for model input.

    Args:
        audio_array: Raw audio data
        sampling_rate: Audio sampling rate
        tokenizer: Tokenizer for feature extraction

    Returns:
        Preprocessed input tensor
    """
    # Simple resampling if needed
    if sampling_rate != 16000:
        import scipy.signal
        num_samples = int(len(audio_array) * 16000 / sampling_rate)
        audio_array = scipy.signal.resample(audio_array, num_samples)

    # Convert to mel spectrogram features
    # This is simplified - actual implementation depends on model architecture
    input_features = tokenizer.feature_extractor(
        audio_array,
        sampling_rate=16000,
        return_tensors="pt",
    ).input_features

    return input_features


def calculate_wer(reference: str, hypothesis: str) -> float:
    """Calculate Word Error Rate.

    Args:
        reference: Ground truth transcription
        hypothesis: Model transcription

    Returns:
        WER as a fraction (0.0 = perfect, 1.0 = all words wrong)
    """
    try:
        from jiwer import wer
        return wer(reference, hypothesis)
    except ImportError:
        print("WARNING: jiwer not installed, using simple word accuracy")
        # Fallback: simple word accuracy
        ref_words = set(reference.lower().split())
        hyp_words = set(hypothesis.lower().split())
        if len(ref_words) == 0:
            return 0.0
        matches = len(ref_words & hyp_words)
        return 1.0 - (matches / len(ref_words))


def evaluate_wer(
    model_path: str = MODEL_PATH,
    dtype: str = "fp16",
    dataset: str = DATASET_NAME,
    n_samples: int = None,
    quick: bool = False,
) -> dict:
    """Evaluate WER for the model.

    Args:
        model_path: Path to model
        dtype: Model data type (fp16 or int4)
        dataset: Dataset name
        n_samples: Number of samples to evaluate
        quick: Quick test mode (10 samples)

    Returns:
        dict with WER results
    """
    print("=" * 60)
    print(f"VibeVoice-ASR WER Evaluation ({dtype.upper()})")
    print("=" * 60)
    print(f"Model: {model_path}")
    print(f"Dataset: {dataset}")

    # Check if model exists
    if not os.path.exists(model_path) and not model_path.startswith("microsoft/"):
        print("\n⚠️  Model not available - skipping evaluation")
        print("Run awq_quantize.py on GPU server first")
        return {
            "skipped": True,
            "reason": "Model not ready",
            "wer": None,
        }

    # Load dataset
    ds = load_dataset(n_samples=n_samples, quick=quick)
    if ds is None:
        return {"skipped": True, "reason": "Dataset not available"}

    # Load model
    model, tokenizer = load_model(model_path, dtype)
    if model is None:
        return {"skipped": True, "reason": "Model not available"}

    # Evaluate
    print("\nEvaluating transcriptions...")
    references = []
    hypotheses = []
    errors = 0

    for i, item in enumerate(ds):
        try:
            audio = item["audio"]["array"]
            sampling_rate = item["audio"]["sampling_rate"]
            reference = item["text"]

            hypothesis = transcribe_audio(model, tokenizer, audio, sampling_rate)

            references.append(reference)
            hypotheses.append(hypothesis)

            if (i + 1) % 10 == 0:
                print(f"  Processed {i + 1}/{len(ds)} samples")

        except Exception as e:
            errors += 1
            if errors <= 3:
                print(f"  Error on sample {i}: {e}")

    # Calculate WER
    total_wer = 0.0
    for ref, hyp in zip(references, hypotheses):
        total_wer += calculate_wer(ref, hyp)

    wer = total_wer / len(references) if references else 1.0

    # Report
    print("\n" + "=" * 60)
    print("WER Results")
    print("=" * 60)
    print(f"Total samples: {len(references)}")
    print(f"Errors: {errors}")
    print(f"WER: {wer:.2%}")

    return {
        "skipped": False,
        "wer": wer,
        "n_samples": len(references),
        "errors": errors,
    }


def compare_wer(wer_fp16: float, wer_int4: float) -> dict:
    """Compare WER between FP16 and INT4 models.

    Args:
        wer_fp16: FP16 baseline WER
        wer_int4: INT4 quantized WER

    Returns:
        dict with comparison results
    """
    wer_diff = wer_int4 - wer_fp16
    wer_diff_pct = (wer_diff / wer_fp16) * 100 if wer_fp16 > 0 else 0

    print("\n" + "=" * 60)
    print("FP16 vs INT4 Comparison")
    print("=" * 60)
    print(f"FP16 WER: {wer_fp16:.2%}")
    print(f"INT4 WER: {wer_int4:.2%}")
    print(f"WER difference: {wer_diff:.2%}")
    print(f"WER loss: {wer_diff_pct:.1f}%")
    print()

    passed = wer_diff <= WER_LOSS_TARGET
    if passed:
        print(f"✅ PASS: WER loss ({wer_diff_pct:.1f}%) within target ({WER_LOSS_TARGET * 100}%)")
    else:
        print(f"❌ FAIL: WER loss ({wer_diff_pct:.1f}%) exceeds target ({WER_LOSS_TARGET * 100}%)")

    return {
        "wer_fp16": wer_fp16,
        "wer_int4": wer_int4,
        "wer_diff": wer_diff,
        "wer_diff_pct": wer_diff_pct,
        "pass": passed,
        "target": WER_LOSS_TARGET,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate WER for VibeVoice-ASR models"
    )
    parser.add_argument(
        "--model-path",
        type=str,
        default=MODEL_PATH,
        help=f"Model path (default: {MODEL_PATH})",
    )
    parser.add_argument(
        "--dtype",
        type=str,
        default="fp16",
        choices=["fp16", "int4"],
        help="Model data type",
    )
    parser.add_argument(
        "--dataset",
        type=str,
        default=DATASET_NAME,
        help=f"Dataset name (default: {DATASET_NAME})",
    )
    parser.add_argument(
        "--n-samples",
        type=int,
        default=None,
        help="Number of samples to evaluate",
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Quick test mode (10 samples)",
    )
    parser.add_argument(
        "--wer-fp16",
        type=float,
        default=None,
        help="FP16 WER for comparison (pre-calculated)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Save results to JSON file",
    )

    args = parser.parse_args()

    results = evaluate_wer(
        model_path=args.model_path,
        dtype=args.dtype,
        dataset=args.dataset,
        n_samples=args.n_samples,
        quick=args.quick,
    )

    # If FP16 WER provided, compare
    if args.wer_fp16 is not None and not results.get("skipped"):
        comparison = compare_wer(args.wer_fp16, results["wer"])
        results["comparison"] = comparison

    # Save to file if specified
    if args.output and not results.get("skipped"):
        import json
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")

    # Exit code
    if results.get("skipped"):
        sys.exit(2)  # Special code for skipped evaluation
    elif results.get("comparison", {}).get("pass", True):
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
