"""
VibeVoice-Realtime-0.5B TTS inference service with streaming output.

Per RESEARCH.md §1.2:
- Primary: vLLM-Omni with VibeVoice-Realtime-0.5B (if compatible)
- Fallback: Qwen3-TTS-12Hz-1.7B-CustomVoice (native vLLM-Omni support)
- Alternative: transformers direct inference

Per RESEARCH.md §1.5: TTFP < 500ms optimization strategies:
- FlashAttention-2 enabled
- bf16 inference
- enforce_eager=True (no CUDA graph)
- chunk duration: 50ms per audio chunk
"""
from typing import AsyncGenerator, Optional
import asyncio
import logging
import numpy as np
import torch

logger = logging.getLogger(__name__)

# Audio parameters (per RESEARCH.md §1.1)
SAMPLE_RATE = 24000
CHANNELS = 1
CHUNK_DURATION_MS = 50  # 50ms per chunk
CHUNK_SIZE_BYTES = SAMPLE_RATE * CHANNELS * 2 * CHUNK_DURATION_MS // 1000  # 2400 bytes per chunk


class VibeVoiceTTSService:
    """
    Streaming TTS service using VibeVoice-Realtime-0.5B.

    Supported voices (mapped to model voice prompts):
    - zh_female_1: Chinese female voice
    - zh_male_1: Chinese male voice
    - en_female_1: English female voice
    - en_male_1: English male voice
    - mixed_1: Neutral bilingual voice
    """

    def __init__(
        self,
        model_path: str = "microsoft/VibeVoice-Realtime-0.5B",
        device: str = "cuda",
        use_vllm: bool = True,
    ):
        self.model_path = model_path
        self.device = device if torch.cuda.is_available() else "cpu"
        self.use_vllm = use_vllm
        self._model = None
        self._tokenizer = None
        self._processor = None
        self._is_loaded = False

        # Voice prompt mappings (per D-04)
        self.voice_prompts = {
            "zh_female_1": None,  # Will load default Chinese female voice
            "zh_male_1": None,
            "en_female_1": None,
            "en_male_1": None,
            "mixed_1": None,
        }

    async def load(self) -> None:
        """Load TTS model into GPU VRAM."""
        if self._is_loaded:
            return

        logger.info(f"Loading TTS model from {self.model_path} on {self.device}")

        if self.use_vllm:
            await self._load_vllm()
        else:
            await self._load_transformers()

        self._is_loaded = True
        logger.info("TTS model loaded successfully")

    async def _load_vllm(self) -> None:
        """Load model using vLLM-Omni for streaming TTS."""
        try:
            # Try vLLM-Omni approach first (per RESEARCH.md §1.2)
            from vllm import LLM, SamplingParams

            # Use lower gpu_memory_utilization to leave room for ASR
            self._model = LLM(
                model=self.model_path,
                trust_remote_code=True,
                tensor_parallel_size=1,
                gpu_memory_utilization=0.5,  # Leave 50% for ASR when needed
                enforce_eager=True,  # Reduce TTFP per §1.5 optimization
            )
            self._sampling_params = SamplingParams(
                max_tokens=2048,
                temperature=0.7,
                top_p=0.9,
            )
            logger.info("Loaded TTS model via vLLM-Omni")
        except Exception as e:
            logger.warning(f"vLLM-Omni failed, falling back to transformers: {e}")
            self.use_vllm = False
            await self._load_transformers()

    async def _load_transformers(self) -> None:
        """Load model using transformers (fallback)."""
        from transformers import AutoModelForCausalLM, AutoTokenizer, AutoProcessor

        self._tokenizer = AutoTokenizer.from_pretrained(
            self.model_path, trust_remote_code=True
        )
        self._processor = AutoProcessor.from_pretrained(
            self.model_path, trust_remote_code=True
        )
        self._model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.bfloat16 if self.device == "cuda" else torch.float32,
            trust_remote_code=True,
            device_map=self.device,
        )
        logger.info("Loaded TTS model via transformers")

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
            torch.cuda.synchronize()

        self._is_loaded = False
        logger.info("TTS model unloaded")

    async def stream_tts(
        self,
        text: str,
        voice_id: str = "zh_female_1",
        cfg_scale: float = 1.5,
        inference_steps: int = 5,
    ) -> AsyncGenerator[tuple[bytes, int, bool], None]:
        """
        Stream TTS audio chunks as they're generated.

        Args:
            text: Input text to synthesize
            voice_id: Voice preset ID
            cfg_scale: Classifier-free guidance scale
            inference_steps: Number of diffusion steps

        Yields:
            tuple[bytes, int, bool]: (PCM16 bytes, chunk_index, is_final)
        """
        if not self._is_loaded:
            raise RuntimeError("Model not loaded. Call load() first.")

        # Validate input
        if not text or not text.strip():
            raise ValueError("Text cannot be empty")

        if len(text) > 8000:
            raise ValueError("Text exceeds maximum length of 8000 characters")

        # Get voice prompt
        voice_prompt = self.voice_prompts.get(voice_id)

        # Estimate total chunks (rough calculation)
        estimated_chars_per_second = 10  # Chinese speech ~10 chars/sec
        estimated_duration_ms = int(len(text) / estimated_chars_per_second * 1000)
        estimated_chunks = max(1, estimated_duration_ms // CHUNK_DURATION_MS)

        logger.info(f"Starting TTS: text_len={len(text)}, voice={voice_id}, estimated_chunks={estimated_chunks}")

        if self.use_vllm:
            async for chunk_data in self._stream_vllm(text, voice_id, cfg_scale, inference_steps):
                yield chunk_data
        else:
            async for chunk_data in self._stream_transformers(text, voice_id, cfg_scale, inference_steps):
                yield chunk_data

    async def _stream_vllm(
        self,
        text: str,
        voice_id: str,
        cfg_scale: float,
        inference_steps: int,
    ) -> AsyncGenerator[tuple[bytes, int, bool], None]:
        """Stream using vLLM model."""
        # vLLM streaming with async iteration
        # This is model-dependent — adjust based on actual vLLM-Omni API
        from vllm.sampling_params import SamplingParams

        # Build input for streaming TTS
        # This is a simplified implementation
        # Real vLLM-Omni integration depends on the specific model interface

        # For now, yield placeholder chunks (to be replaced with actual vLLM streaming)
        chunk_index = 0
        total_yielded = 0

        # Simulate streaming with asyncio.sleep for development
        # Replace this with actual vLLM streaming when model is validated
        while total_yielded < 10:  # Yield 10 chunks for demo
            await asyncio.sleep(0.05)  # 50ms delay per chunk

            # Generate dummy audio data (replace with actual model output)
            pcm_data = self._generate_silent_chunk()

            is_final = total_yielded >= 9
            yield (pcm_data, chunk_index, is_final)

            chunk_index += 1
            total_yielded += 1

    async def _stream_transformers(
        self,
        text: str,
        voice_id: str,
        cfg_scale: float,
        inference_steps: int,
    ) -> AsyncGenerator[tuple[bytes, int, bool], None]:
        """Stream using transformers model."""
        if self._processor is None:
            raise RuntimeError("Processor not available")

        # Prepare inputs
        inputs = self._processor(
            text=[text],
            return_tensors="pt",
            padding=True,
        )
        inputs = {k: v.to(self.device) for k, v in inputs.items()}

        # Run streaming generation in thread pool
        loop = asyncio.get_event_loop()
        chunks = await loop.run_in_executor(
            None,
            self._generate_streaming,
            inputs,
            voice_id,
            cfg_scale,
            inference_steps,
        )

        # Yield chunks asynchronously
        for i, pcm_chunk in enumerate(chunks):
            is_final = (i == len(chunks) - 1)
            yield (pcm_chunk, i, is_final)
            await asyncio.sleep(0.01)  # Small delay for streaming effect

    def _generate_streaming(
        self,
        inputs: dict,
        voice_id: str,
        cfg_scale: float,
        inference_steps: int,
    ) -> list[bytes]:
        """Generate streaming audio chunks (runs in thread pool)."""
        # This is a placeholder implementation
        # Real implementation depends on VibeVoice-Realtime model architecture
        chunks = []
        for _ in range(10):
            pcm = self._generate_silent_chunk()
            chunks.append(pcm)
        return chunks

    def _generate_silent_chunk(self) -> bytes:
        """Generate a silent audio chunk (placeholder)."""
        # Generate 50ms of silence (2400 bytes for 24kHz mono PCM16)
        silent_samples = np.zeros(CHUNK_SIZE_BYTES // 2, dtype=np.int16)
        return silent_samples.tobytes()

    def pcm_to_bytes(self, pcm: np.ndarray) -> bytes:
        """Convert float32 PCM [-1, 1] to int16 bytes."""
        int16_pcm = np.clip(pcm, -1.0, 1.0)
        int16_pcm = (int16_pcm * 32767).astype(np.int16)
        return int16_pcm.tobytes()

    @property
    def model_name(self) -> str:
        """Return the model name for metadata."""
        return self.model_path.split("/")[-1]


# Global service instance (created by ModelManager)
tts_service: Optional["VibeVoiceTTSService"] = None
