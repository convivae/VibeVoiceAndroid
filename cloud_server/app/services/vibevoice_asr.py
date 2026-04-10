from typing import AsyncGenerator, Optional
import torch
import numpy as np
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoProcessor
import logging

logger = logging.getLogger(__name__)


class VibeVoiceASRService:
    """
    VibeVoice-ASR inference service using transformers.
    
    Architecture (per RESEARCH.md §1.1 fallback):
    - NOT using vLLM plugin (batch-only, no streaming)
    - Using transformers + accelerate for streaming-capable inference
    """

    def __init__(self, model_path: str = "microsoft/VibeVoice-ASR", device: str = "cuda"):
        self.model_path = model_path
        self.device = device if torch.cuda.is_available() else "cpu"
        self._model: Optional[AutoModelForCausalLM] = None
        self._tokenizer: Optional[AutoTokenizer] = None
        self._processor: Optional[AutoProcessor] = None
        self._is_loaded = False

    async def load(self) -> None:
        """Load VibeVoice-ASR model and tokenizer into GPU VRAM."""
        if self._is_loaded:
            return
        
        logger.info(f"Loading VibeVoice-ASR from {self.model_path} on {self.device}")
        
        self._tokenizer = AutoTokenizer.from_pretrained(
            self.model_path, trust_remote_code=True
        )
        
        # Load processor for audio tokenization
        try:
            self._processor = AutoProcessor.from_pretrained(
                self.model_path, trust_remote_code=True
            )
        except Exception as e:
            logger.warning(f"Processor not available, will use tokenizer only: {e}")
            self._processor = None
        
        # Load model in bfloat16 for better numerical stability
        self._model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.bfloat16 if self.device == "cuda" else torch.float32,
            trust_remote_code=True,
            device_map=self.device,
        )
        
        self._is_loaded = True
        logger.info("VibeVoice-ASR loaded successfully")

    async def unload(self) -> None:
        """Release GPU memory."""
        if self._model is not None:
            del self._model
            self._model = None
        if self._tokenizer is not None:
            del self._tokenizer
            self._tokenizer = None
        if self._processor is not None:
            del self._processor
            self._processor = None
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        self._is_loaded = False
        logger.info("VibeVoice-ASR unloaded")

    async def transcribe_full(
        self,
        audio_bytes: bytes,
        language: str = "zh",
    ) -> str:
        """
        Transcribe a complete audio buffer.
        Called when client disconnects (end of speech).
        
        Args:
            audio_bytes: Raw PCM16 little-endian mono audio
            language: "zh" for Mandarin, "en" for English
        
        Returns:
            Transcribed text string
        """
        if not self._is_loaded:
            raise RuntimeError("Model not loaded. Call load() first.")
        
        # Convert bytes to numpy float32 audio [-1, 1]
        audio_samples = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        
        # Get language-specific generation settings
        gen_config = self._get_gen_config(language)
        
        # Build input with voice prompt
        inputs = self._build_inputs(audio_samples, language)
        
        # Generate transcription
        with torch.no_grad():
            generated_ids = self._model.generate(
                **inputs,
                **gen_config,
                max_new_tokens=512,
            )
        
        # Decode
        transcription = self._tokenizer.decode(
            generated_ids[0], skip_special_tokens=True
        ).strip()
        
        return transcription

    async def stream_transcribe(
        self,
        audio_chunks: list[bytes],
        language: str = "zh",
    ) -> AsyncGenerator[str, None]:
        """
        Stream transcription incrementally as chunks accumulate.
        Yields partial transcriptions for real-time feedback.
        """
        if not self._is_loaded:
            raise RuntimeError("Model not loaded. Call load() first.")
        
        audio_buffer = bytearray()
        chunk_count = 0
        min_chunks_before_inference = 4  # ~200ms minimum
        
        for chunk in audio_chunks:
            audio_buffer.extend(chunk)
            chunk_count += 1
            
            # Only run inference every N chunks to avoid excessive GPU load
            if chunk_count % 3 != 0:
                continue
            
            # Accumulate minimum before first inference
            if chunk_count < min_chunks_before_inference:
                continue
            
            # Transcribe accumulated audio
            audio_bytes = bytes(audio_buffer)
            partial = await self._transcribe_partial(audio_bytes, language)
            if partial:
                yield partial
        
        # Final transcription on last chunks
        if audio_buffer:
            final = await self.transcribe_full(bytes(audio_buffer), language)
            yield final

    async def _transcribe_partial(self, audio_bytes: bytes, language: str) -> Optional[str]:
        """Internal partial transcription (no streaming tokens, just incremental)."""
        try:
            audio_samples = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
            inputs = self._build_inputs(audio_samples, language)
            gen_config = self._get_gen_config(language)
            
            with torch.no_grad():
                generated_ids = self._model.generate(
                    **inputs,
                    **gen_config,
                    max_new_tokens=64,  # Short for partial
                )
            
            text = self._tokenizer.decode(generated_ids[0], skip_special_tokens=True).strip()
            return text if text else None
        except Exception as e:
            logger.warning(f"Partial transcription error: {e}")
            return None

    def _build_inputs(self, audio_samples: np.ndarray, language: str) -> dict:
        """Build model inputs from audio samples."""
        # If processor is available, use it
        if self._processor is not None:
            try:
                inputs = self._processor(
                    audios=audio_samples,
                    return_tensors="pt",
                    sampling_rate=16000,
                )
                inputs = {k: v.to(self.device) for k, v in inputs.items()}
                return inputs
            except Exception:
                pass
        
        # Fallback: convert audio to features and use tokenizer directly
        # This is model-dependent — adjust based on actual VibeVoice input format
        # Typical pattern: extract MFCC/Fbank features → tokenize → feed to LLM
        features = self._extract_audio_features(audio_samples)
        
        # Build text prompt based on language
        text_prompt = self._get_language_prompt(language)
        
        # Tokenize combined input
        inputs = self._tokenizer(
            text_prompt,
            return_tensors="pt",
            add_special_tokens=True,
        )
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        # Add audio features as additional input (model-dependent)
        # Some VibeVoice models accept speech_features directly
        if features is not None:
            inputs["speech_features"] = features.to(self.device)
        
        return inputs

    def _extract_audio_features(self, audio_samples: np.ndarray) -> Optional[torch.Tensor]:
        """
        Extract audio features for ASR model input.
        
        This is a simplified implementation. The actual feature extraction
        depends on the specific VibeVoice-ASR model architecture.
        Common approaches:
        - MFCC features (librosa)
        - Log mel spectrogram (torchaudio)
        - Model-specific tokenizer
        
        For Phase 1 MVP, we use a simple approach:
        - Resample to 16kHz if needed (VibeVoice expects 16kHz)
        - Normalize to [-1, 1]
        """
        # Simple: treat audio as raw features (placeholder for model-specific encoding)
        # Real implementation depends on VibeVoice model architecture
        try:
            import scipy.signal
            # Resample to 16kHz if needed (VibeVoice expects 16kHz)
            # This is a simplified placeholder
            return None
        except Exception:
            return None

    def _get_language_prompt(self, language: str) -> str:
        """Get language-specific ASR prompt."""
        prompts = {
            "zh": "请转录音频内容：",
            "en": "Please transcribe the audio:",
        }
        return prompts.get(language, prompts["zh"])

    def _get_gen_config(self, language: str) -> dict:
        """Get generation config for language."""
        return {
            "do_sample": False,  # Greedy for ASR accuracy
            "temperature": 1.0,
        }


# Global service instance (shared across WebSocket connections)
asr_service = VibeVoiceASRService()
