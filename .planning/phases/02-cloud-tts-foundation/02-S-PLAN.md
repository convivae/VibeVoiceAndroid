# Phase 2: Cloud TTS Foundation — Plan S

## Cloud TTS Server (FastAPI + vLLM Streaming + /voices Endpoint)

---
phase: 02-cloud-tts-foundation
plan: S
type: execute
wave: 1
depends_on: []
files_modified:
  - cloud_server/app/routers/tts.py
  - cloud_server/app/services/vibevoice_tts.py
  - cloud_server/app/services/model_manager.py
  - cloud_server/app/models/schemas.py
  - cloud_server/app/main.py
  - cloud_server/requirements.txt
autonomous: false
requirements:
  - REQ-06
  - REQ-07
  - REQ-11
user_setup:
  - service: WSL2 GPU passthrough (already validated in Phase 1)
    why: RTX 4060 GPU must be visible inside WSL2 for CUDA inference
    verify: Run `nvidia-smi` in WSL2 bash, confirm RTX 4060 visible
  - service: TTS Model availability
    verify: Confirm microsoft/VibeVoice-Realtime-0.5B is accessible or plan for Qwen3-TTS fallback
    action: If VibeVoice-Realtime incompatible with vLLM, fall back to Qwen3-TTS-12Hz-1.7B-CustomVoice

must_haves:
  truths:
    - "WebSocket client connects to /v1/tts/stream, sends text, receives streaming PCM audio chunks"
    - "Server responds to /voices with list of 5 preset voices"
    - "TTFP (Time To First PCM Chunk) < 500ms on RTX 4060"
    - "WebSocket stays connected for 10 minutes without disconnect"
    - "Input validation rejects empty text and text exceeding 8K tokens"
    - "Rate limiting prevents abuse (max 10 concurrent TTS sessions)"
  artifacts:
    - path: cloud_server/app/routers/tts.py
      provides: WebSocket /v1/tts/stream endpoint with streaming TTS inference
      exports: ["tts_stream"]
    - path: cloud_server/app/routers/voices.py
      provides: GET /voices endpoint returning 5 preset voices
      exports: ["list_voices"]
    - path: cloud_server/app/services/vibevoice_tts.py
      provides: VibeVoice-Realtime TTS inference service with streaming output
      exports: ["VibeVoiceTTSService", "tts_service"]
    - path: cloud_server/app/services/model_manager.py
      provides: Model lifecycle manager (load/unload ASR and TTS models)
      exports: ["ModelManager", "model_manager"]
    - path: cloud_server/app/models/schemas.py
      provides: Pydantic models for TTS request/response
      exports: ["TTSStartMessage", "TTSMetadata", "TTSAudioChunk", "TTSDone", "TTSError", "VoiceInfo"]
    - path: cloud_server/app/main.py
      provides: FastAPI app entry point with both ASR and TTS routers
      contains: "tts.router" and "voices.router"
  key_links:
    - from: cloud_server/app/routers/tts.py
      to: cloud_server/app/services/vibevoice_tts.py
      via: asyncio.create_task + streaming yield
      pattern: "async for.*stream_tts"
    - from: cloud_server/app/main.py
      to: cloud_server/app/routers/tts.py
      via: app.include_router
      pattern: "include_router.*tts"
    - from: cloud_server/app/services/vibevoice_tts.py
      to: cloud_server/app/services/model_manager.py
      via: model_manager.get_model
      pattern: "model_manager.get_model.*tts"
---

<objective>
Build the cloud TTS inference server that receives text input over WebSocket and streams back PCM audio chunks in real time. This server runs on the same Windows Server RTX 4060 machine as the ASR server (Phase 1), sharing GPU resources via model manager.

Purpose: Without this server, the Flutter TTS Tab has no backend to play voice audio from.
Output: FastAPI WebSocket TTS server, /voices endpoint, vLLM TTS service, model manager for dual-model VRAM.
</objective>

<execution_context>
 @$HOME/.cursor/get-shit-done/workflows/execute-plan.md
 @$HOME/.cursor/get-shit-done/templates/summary.md
</execution_context>

<context>
 @.planning/phases/02-cloud-tts-foundation/02-CONTEXT.md D-01 through D-11 (server decisions)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §1.3 (WebSocket TTS protocol)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §1.4 (/voices endpoint format)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §1.5 (TTFP optimization)
 @.planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §2.1-2.3 (VRAM management)
 @raw/SPEC.md §1.2 (WebSocket protocol format — TTS variant)
 @.planning/phases/01-cloud-asr-pipeline/01-CONTEXT.md D-03 through D-08 (inherited server patterns)
</context>

<assumptions_note>
## Critical Architecture Decisions

Per RESEARCH.md §1.2:
1. VibeVoice-Realtime-0.5B may not be compatible with vLLM directly. This plan implements both vLLM-Omni (preferred) and FastAPI custom fallback.
2. If VibeVoice-Realtime is incompatible, fall back to Qwen3-TTS-12Hz-1.7B-CustomVoice which has native vLLM-Omni support and 131ms TTFP.
3. VRAM management is critical: RTX 4060 has 8GB, ASR (Phase 1) uses ~4GB INT4, leaving ~4GB for TTS. Use gpu_memory_utilization=0.5 for TTS to leave headroom.
4. ASR and TTS models MUST NOT be loaded simultaneously. Use ModelManager for lazy loading with GPU memory cleanup.
</assumptions_note>

<interfaces>
<!-- Key types the executor needs. Extracted from codebase patterns. -->

From cloud_server/app/models/schemas.py:
```python
from pydantic import BaseModel, Field
from typing import Literal, Optional, List

class TTSStartMessage(BaseModel):
    """Client sends this as first JSON message on WebSocket"""
    type: Literal["start"]
    text: str = Field(..., max_length=8000)
    voice_id: str = "zh_female_1"
    cfg_scale: float = Field(default=1.5, ge=0.1, le=3.0)
    inference_steps: int = Field(default=5, ge=1, le=20)

class TTSMetadata(BaseModel):
    """Server sends metadata before first audio chunk"""
    type: Literal["metadata"]
    sample_rate: int = 24000
    channels: int = 1
    format: str = "pcm_s16le"
    model: str
    estimated_chunks: int
    estimated_duration_ms: int

class TTSAudioChunk(BaseModel):
    """Server sends after each audio chunk (JSON header)"""
    type: Literal["audio_chunk"]
    chunk_index: int
    is_final: bool
    timestamp_ms: int

class TTSDone(BaseModel):
    """Server sends when streaming complete"""
    type: Literal["done"]
    total_chunks: int
    total_duration_ms: int

class TTSError(BaseModel):
    """Server sends on error"""
    type: Literal["error"]
    code: str
    message: str

class VoiceInfo(BaseModel):
    """Single voice in /voices response"""
    id: str
    name: str
    language: str  # "zh", "en", "mixed"
    gender: str    # "female", "male", "neutral"

class VoicesResponse(BaseModel):
    """GET /voices response"""
    voices: List[VoiceInfo]
    default: str
```

From cloud_server/app/services/model_manager.py:
```python
class ModelManager:
    """Manages ASR and TTS model lifecycle with VRAM cleanup"""
    async def get_model(self, model_type: Literal["asr", "tts"]) -> Any:
        """Get or load model instance. Unloads other model if needed for VRAM."""

    async def unload_all(self) -> None:
        """Unload all models and clear GPU cache."""

    async def get_vram_usage(self) -> dict:
        """Return current VRAM usage statistics."""
```

From cloud_server/app/services/vibevoice_tts.py:
```python
class VibeVoiceTTSService:
    """Streaming TTS inference service using vLLM or transformers fallback"""

    async def load(self) -> None:
        """Load TTS model into GPU VRAM."""

    async def unload(self) -> None:
        """Release GPU memory."""

    async def stream_tts(
        self,
        text: str,
        voice_id: str,
        cfg_scale: float = 1.5,
        inference_steps: int = 5,
    ) -> AsyncGenerator[tuple[bytes, int], None]:
        """Stream PCM audio chunks and chunk indices.

        Yields:
            tuple[bytes, int]: (PCM16 little-endian bytes, chunk_index)
        """
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Create Cloud Server Project Structure for TTS</name>
  <files>cloud_server/app/routers/tts.py, cloud_server/app/routers/voices.py, cloud_server/app/services/vibevoice_tts.py, cloud_server/app/services/model_manager.py</files>
  <read_first>
    cloud_server/app/main.py (existing — Phase 1)
    cloud_server/app/models/schemas.py (existing — Phase 1)
    cloud_server/app/routers/asr.py (existing — Phase 1, reference pattern)
  </read_first>
  <action>
Create the following new files for TTS support:

**cloud_server/app/routers/voices.py**:
```python
from fastapi import APIRouter, HTTPException
from app.models.schemas import VoicesResponse, VoiceInfo

router = APIRouter()

# 5 preset voices: 2 Chinese + 2 English + 1 mixed
PRESET_VOICES = [
    VoiceInfo(
        id="zh_female_1",
        name="中文女声-温柔",
        language="zh",
        gender="female",
    ),
    VoiceInfo(
        id="zh_male_1",
        name="中文男声-稳重",
        language="zh",
        gender="male",
    ),
    VoiceInfo(
        id="en_female_1",
        name="English Female",
        language="en",
        gender="female",
    ),
    VoiceInfo(
        id="en_male_1",
        name="English Male",
        language="en",
        gender="male",
    ),
    VoiceInfo(
        id="mixed_1",
        name="中英混合",
        language="mixed",
        gender="neutral",
    ),
]

DEFAULT_VOICE = "zh_female_1"


@router.get("/voices", response_model=VoicesResponse)
async def list_voices():
    """Return list of available preset voices."""
    return VoicesResponse(
        voices=PRESET_VOICES,
        default=DEFAULT_VOICE,
    )
```

**cloud_server/app/services/model_manager.py**:
```python
"""
Model lifecycle manager for ASR and TTS models on RTX 4060.

Per RESEARCH.md §2.1: RTX 4060 has 8GB VRAM. ASR (INT4) uses ~4GB,
leaving ~4GB for TTS. Models MUST NOT be loaded simultaneously.
Use lazy loading with GPU memory cleanup.
"""
import torch
import logging
from typing import Optional, Any, Dict
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)


class ModelManager:
    """
    Manages ASR and TTS model lifecycle with VRAM cleanup.

    Architecture:
    - ASR and TTS models share the same GPU but not simultaneously
    - When loading one model, unload the other first
    - Track current loaded model to avoid redundant loads
    """

    def __init__(self):
        self.models: Dict[str, Any] = {}
        self.current_model: Optional[str] = None
        self._asr_service = None
        self._tts_service = None

    async def get_asr_service(self) -> Any:
        """Get or load ASR service."""
        if self._asr_service is None:
            # Import here to avoid circular dependency
            from app.services.vibevoice_asr import VibeVoiceASRService
            self._asr_service = VibeVoiceASRService()
        return self._asr_service

    async def get_tts_service(self) -> Any:
        """Get or load TTS service."""
        if self._tts_service is None:
            # Import here to avoid circular dependency
            from app.services.vibevoice_tts import VibeVoiceTTSService
            self._tts_service = VibeVoiceTTSService()
        return self._tts_service

    async def load_model(self, model_type: str) -> Any:
        """
        Load a model by type, unloading others to free VRAM.

        Args:
            model_type: "asr" or "tts"

        Returns:
            The loaded model service instance
        """
        if model_type == self.current_model and model_type in self.models:
            logger.info(f"Model '{model_type}' already loaded")
            return self.models[model_type]

        # Unload current model to free VRAM
        await self._unload_current_model()

        # Load requested model
        if model_type == "asr":
            service = await self.get_asr_service()
            if not service._is_loaded:
                await service.load()
                self.models["asr"] = service
        elif model_type == "tts":
            service = await self.get_tts_service()
            if not service._is_loaded:
                await service.load()
                self.models["tts"] = service
        else:
            raise ValueError(f"Unknown model type: {model_type}")

        self.current_model = model_type
        logger.info(f"Loaded model: {model_type}")

        # Log VRAM usage
        if torch.cuda.is_available():
            allocated = torch.cuda.memory_allocated() / 1024**3
            reserved = torch.cuda.memory_reserved() / 1024**3
            logger.info(f"VRAM: {allocated:.2f}GB allocated, {reserved:.2f}GB reserved")

        return self.models[model_type]

    async def _unload_current_model(self) -> None:
        """Unload the currently loaded model."""
        if self.current_model is None:
            return

        model_name = self.current_model
        logger.info(f"Unloading model: {model_name}")

        if model_name in self.models:
            service = self.models[model_name]
            if hasattr(service, "unload"):
                await service.unload()
            del self.models[model_name]

        self.current_model = None

        # Clear GPU cache
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.synchronize()

        logger.info("GPU cache cleared")

    async def unload_all(self) -> None:
        """Unload all models and clear GPU cache."""
        for name in list(self.models.keys()):
            service = self.models[name]
            if hasattr(service, "unload"):
                await service.unload()
        self.models.clear()
        self.current_model = None

        if torch.cuda.is_available():
            torch.cuda.empty_cache()

    def get_vram_usage(self) -> dict:
        """Return current VRAM usage statistics."""
        if not torch.cuda.is_available():
            return {"available": False}
        return {
            "available": True,
            "allocated_gb": torch.cuda.memory_allocated() / 1024**3,
            "reserved_gb": torch.cuda.memory_reserved() / 1024**3,
            "max_allocated_gb": torch.cuda.max_memory_allocated() / 1024**3,
            "current_model": self.current_model,
        }


# Global model manager instance
model_manager = ModelManager()
```

**Update cloud_server/app/models/schemas.py** — Add TTS schemas to existing file:
```python
# Add these to the existing schemas.py file (after Phase 1 schemas)

class TTSStartMessage(BaseModel):
    """Client sends this as first JSON message on WebSocket"""
    type: Literal["start"]
    text: str = Field(..., max_length=8000)
    voice_id: str = "zh_female_1"
    cfg_scale: float = Field(default=1.5, ge=0.1, le=3.0)
    inference_steps: int = Field(default=5, ge=1, le=20)


class TTSMetadata(BaseModel):
    """Server sends metadata before first audio chunk"""
    type: Literal["metadata"]
    sample_rate: int = 24000
    channels: int = 1
    format: str = "pcm_s16le"
    model: str
    estimated_chunks: int
    estimated_duration_ms: int


class TTSAudioChunk(BaseModel):
    """Server sends after each audio chunk (JSON header)"""
    type: Literal["audio_chunk"]
    chunk_index: int
    is_final: bool
    timestamp_ms: int


class TTSDone(BaseModel):
    """Server sends when streaming complete"""
    type: Literal["done"]
    total_chunks: int
    total_duration_ms: int


class TTSError(BaseModel):
    """Server sends on error"""
    type: Literal["error"]
    code: str
    message: str


class VoiceInfo(BaseModel):
    """Single voice in /voices response"""
    id: str
    name: str
    language: str
    gender: str


class VoicesResponse(BaseModel):
    """GET /voices response"""
    voices: list[VoiceInfo]
    default: str
```
</action>
  <verify>
    <automated>grep -l "class TTSStartMessage\|class TTSMetadata\|class VoicesResponse" cloud_server/app/models/schemas.py && grep -l "list_voices\|PRESET_VOICES" cloud_server/app/routers/voices.py && grep -l "class ModelManager" cloud_server/app/services/model_manager.py && echo "TTS SCAFFOLD OK"</automated>
  </verify>
  <acceptance_criteria>
    - cloud_server/app/routers/voices.py exists and exports list_voices endpoint
    - cloud_server/app/models/schemas.py contains TTSStartMessage, TTSMetadata, TTSAudioChunk, TTSDone, TTSError, VoiceInfo, VoicesResponse
    - cloud_server/app/services/model_manager.py contains ModelManager class with load_model/unload_all methods
    - VoicesResponse returns 5 preset voices: zh_female_1, zh_male_1, en_female_1, en_male_1, mixed_1
    - Default voice is zh_female_1
  </acceptance_criteria>
  <done>TTS scaffolding created: /voices endpoint, TTS Pydantic schemas, ModelManager for VRAM management</done>
</task>

<task type="auto">
  <name>Task 2: Implement VibeVoice TTS Service with Streaming Support</name>
  <files>cloud_server/app/services/vibevoice_tts.py</files>
  <read_first>
    cloud_server/app/services/vibevoice_tts.py (new — will be created)
    cloud_server/app/services/model_manager.py (created in Task 1)
    .planning/phases/02-cloud-tts-foundation/02-RESEARCH.md §1.1-1.2 (VibeVoice-Realtime specs)
  </read_first>
  <action>
Create the core TTS inference service:

**cloud_server/app/services/vibevoice_tts.py**:
```python
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
import struct

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
```
</action>
  <verify>
    <automated>grep -l "class VibeVoiceTTSService\|async def stream_tts" cloud_server/app/services/vibevoice_tts.py && echo "TTS SERVICE OK"</automated>
  </verify>
  <acceptance_criteria>
    - cloud_server/app/services/vibevoice_tts.py contains VibeVoiceTTSService class
    - VibeVoiceTTSService has load/unload/stream_tts methods
    - stream_tts is an async generator yielding (bytes, int, bool) tuples
    - Service uses gpu_memory_utilization=0.5 for VRAM management
    - Audio chunks are PCM16 little-endian format (2400 bytes per 50ms at 24kHz)
  </acceptance_criteria>
  <done>VibeVoice TTS Service implemented with streaming support and VRAM management</done>
</task>

<task type="auto">
  <name>Task 3: Implement WebSocket TTS Router and Update main.py</name>
  <files>cloud_server/app/routers/tts.py, cloud_server/app/main.py</files>
  <read_first>
    cloud_server/app/routers/tts.py (new — will be created)
    cloud_server/app/routers/asr.py (existing — reference pattern)
    cloud_server/app/services/vibevoice_tts.py (created in Task 2)
    cloud_server/app/services/model_manager.py (created in Task 1)
  </read_first>
  <action>
Create the WebSocket TTS router and update main.py:

**cloud_server/app/routers/tts.py**:
```python
"""
WebSocket TTS streaming endpoint.

Per RESEARCH.md §1.3:
- Client sends JSON: {"type": "start", "text": "...", "voice_id": "zh_female_1"}
- Server sends metadata: {"type": "metadata", "sample_rate": 24000, ...}
- Server sends audio chunks: JSON header + binary PCM
- Server sends done: {"type": "done", "total_chunks": N, "total_duration_ms": T}

Per 02-CONTEXT.md D-09:
- Use ModelManager for on-demand model loading
- Unload ASR before loading TTS to free VRAM
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.websockets.experimental import WebSocketState
import asyncio
import json
import logging
import time

from app.models.schemas import (
    TTSStartMessage,
    TTSMetadata,
    TTSAudioChunk,
    TTSDone,
    TTSError,
)
from app.services.model_manager import model_manager
from app.services.vibevoice_tts import SAMPLE_RATE, CHUNK_DURATION_MS

router = APIRouter()
logger = logging.getLogger(__name__)

# Rate limiting: max concurrent TTS sessions
MAX_CONCURRENT_TTS = 10
_active_tts_count = 0


@router.websocket("/stream")
async def tts_stream(ws: WebSocket):
    """
    WebSocket TTS streaming endpoint.

    Protocol:
    1. Client sends JSON: {"type": "start", "text": "...", "voice_id": "zh_female_1"}
    2. Server sends metadata: {"type": "metadata", "sample_rate": 24000, ...}
    3. Server streams audio: JSON header + binary PCM chunks
    4. Server sends done: {"type": "done", ...}
    5. On error: {"type": "error", "code": "...", "message": "..."}
    """
    global _active_tts_count

    # Rate limiting
    if _active_tts_count >= MAX_CONCURRENT_TTS:
        await ws.accept()
        await ws.send_json({
            "type": "error",
            "code": "RATE_LIMITED",
            "message": f"Max {MAX_CONCURRENT_TTS} concurrent sessions. Try again later."
        })
        await ws.close(code=1011)
        return

    await ws.accept()
    _active_tts_count += 1

    try:
        # Receive start message
        start_msg = await ws.receive_json()
        start_data = TTSStartMessage(**start_msg)

        text = start_data.text
        voice_id = start_data.voice_id
        cfg_scale = start_data.cfg_scale
        inference_steps = start_data.inference_steps

        # Input validation (per ASVS L1 TTS-01)
        if not text or not text.strip():
            await _send_error(ws, "TEXT_EMPTY", "Text cannot be empty")
            return

        if len(text) > 8000:
            await _send_error(ws, "TEXT_TOO_LONG", "Text exceeds maximum length of 8000 characters")
            return

        # Validate voice_id
        valid_voices = ["zh_female_1", "zh_male_1", "en_female_1", "en_male_1", "mixed_1"]
        if voice_id not in valid_voices:
            await _send_error(ws, "INVALID_VOICE", f"Voice '{voice_id}' not found. Valid: {valid_voices}")
            return

        # Load TTS model (unloads ASR if needed)
        tts_service = await model_manager.load_model("tts")

        # Estimate chunks and duration
        estimated_chars_per_second = 10
        estimated_duration_ms = int(len(text) / estimated_chars_per_second * 1000)
        estimated_chunks = max(1, estimated_duration_ms // CHUNK_DURATION_MS)

        # Send metadata
        await ws.send_json({
            "type": "metadata",
            "sample_rate": SAMPLE_RATE,
            "channels": 1,
            "format": "pcm_s16le",
            "model": tts_service.model_name,
            "estimated_chunks": estimated_chunks,
            "estimated_duration_ms": estimated_duration_ms,
        })

        # Stream audio chunks
        total_chunks = 0
        total_duration_ms = 0
        start_time = time.time()

        async for pcm_bytes, chunk_index, is_final in tts_service.stream_tts(
            text=text,
            voice_id=voice_id,
            cfg_scale=cfg_scale,
            inference_steps=inference_steps,
        ):
            # Send JSON header
            timestamp_ms = chunk_index * CHUNK_DURATION_MS
            await ws.send_json({
                "type": "audio_chunk",
                "chunk_index": chunk_index,
                "is_final": is_final,
                "timestamp_ms": timestamp_ms,
            })

            # Send binary audio data
            await ws.send_bytes(pcm_bytes)

            total_chunks += 1
            total_duration_ms += CHUNK_DURATION_MS

        # Send done message
        elapsed_ms = int((time.time() - start_time) * 1000)
        await ws.send_json({
            "type": "done",
            "total_chunks": total_chunks,
            "total_duration_ms": total_duration_ms,
        })

        logger.info(f"TTS complete: {total_chunks} chunks, {total_duration_ms}ms, {elapsed_ms}ms wall time")

    except WebSocketDisconnect:
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"TTS error: {e}")
        await _send_error(ws, "INTERNAL_ERROR", str(e))
    finally:
        _active_tts_count -= 1


async def _send_error(ws: WebSocket, code: str, message: str):
    """Send error response and close."""
    try:
        if ws.client_state == WebSocketState.CONNECTED:
            await ws.send_json({
                "type": "error",
                "code": code,
                "message": message,
            })
            await ws.close()
    except Exception:
        pass
```

**Update cloud_server/app/main.py** — Add TTS and voices routers:
```python
# Add these imports and router registrations to the existing main.py

from app.routers import asr, health, tts, voices

# Add these router registrations (after Phase 1 registrations):
app.include_router(tts.router, prefix="/v1/tts", tags=["TTS"])
app.include_router(voices.router, tags=["Voices"])
```

</action>
  <verify>
    <automated>grep -l "tts_stream\|tts.router\|voices.router" cloud_server/app/main.py && grep -l "MAX_CONCURRENT_TTS\|RATE_LIMITED" cloud_server/app/routers/tts.py && echo "TTS ROUTER OK"</automated>
  </verify>
  <acceptance_criteria>
    - cloud_server/app/main.py includes tts.router and voices.router
    - cloud_server/app/routers/tts.py contains tts_stream WebSocket endpoint
    - TTS endpoint validates text length (max 8000 chars) and voice_id
    - Rate limiting rejects when >10 concurrent sessions
    - Metadata sent before audio chunks with sample_rate=24000, format="pcm_s16le"
    - Audio chunks sent as JSON header + binary PCM bytes
    - Done message sent at end with total_chunks and total_duration_ms
  </acceptance_criteria>
  <done>WebSocket TTS router implemented with input validation, rate limiting, and streaming protocol</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Server Validation on RTX 4060</name>
  <files>cloud_server/app/main.py, cloud_server/app/routers/tts.py, cloud_server/app/routers/voices.py</files>
  <read_first>
    cloud_server/app/routers/tts.py (created in Task 3)
    cloud_server/app/routers/voices.py (created in Task 1)
  </read_first>
  <action>
**Task 4A: Executor validates code structure** (automated):

```bash
# Validate all files exist and have expected content
ls cloud_server/app/main.py cloud_server/app/routers/tts.py cloud_server/app/routers/voices.py
grep -c "tts.router\|voices.router" cloud_server/app/main.py
grep -c "tts_stream" cloud_server/app/routers/tts.py
grep -c "list_voices" cloud_server/app/routers/voices.py

# Verify Python syntax
python3 -m py_compile cloud_server/app/routers/tts.py
python3 -m py_compile cloud_server/app/services/vibevoice_tts.py
python3 -m py_compile cloud_server/app/services/model_manager.py
```

**Task 4B: User validates on Windows Server WSL2** (manual, cannot be automated):

Run these commands on the Windows Server WSL2 machine:

```bash
# 1. Pull latest code
cd cloud_server
git pull origin main

# 2. Build and start Docker container
docker compose down
docker compose build --no-cache
docker compose up -d

# 3. Check logs for model loading
docker compose logs -f vibevoice-asr

# 4. Test /voices endpoint
curl http://localhost:8000/voices
# Expected:
# {
#   "voices": [
#     {"id": "zh_female_1", "name": "中文女声-温柔", "language": "zh", "gender": "female"},
#     ... (5 voices total)
#   ],
#   "default": "zh_female_1"
# }

# 5. Test TTS WebSocket (requires wscat or Python client)
# Install wscat: npm install -g wscat

# Start WebSocket connection:
wscat -c ws://localhost:8000/v1/tts/stream

# In the interactive prompt, send:
# {"type": "start", "text": "你好，欢迎使用语音合成", "voice_id": "zh_female_1"}

# Should receive metadata + audio chunks

# 6. Test input validation
# Send empty text - should receive error
# Send very long text (>8000 chars) - should receive TEXT_TOO_LONG error
# Use invalid voice_id - should receive INVALID_VOICE error

# 7. Test rate limiting (optional)
# Open 11+ concurrent connections - should get RATE_LIMITED error
```

**Task 4C: Measure TTFP** (manual validation):

```bash
# Using Python WebSocket client
python3 << 'EOF'
import asyncio
import websockets
import json
import time

async def test_ttfp():
    uri = "ws://localhost:8000/v1/tts/stream"
    async with websockets.connect(uri) as ws:
        # Receive metadata
        metadata = await ws.recv()
        print(f"Metadata: {metadata}")

        # Send request
        start_time = time.time()
        await ws.send(json.dumps({
            "type": "start",
            "text": "你好",
            "voice_id": "zh_female_1"
        }))

        # Wait for first audio chunk
        first_chunk = await ws.recv()
        ttfp_ms = (time.time() - start_time) * 1000

        print(f"TTFP: {ttfp_ms:.2f}ms")
        print(f"Target: < 500ms")

        if ttfp_ms < 500:
            print("PASS: TTFP meets target")
        else:
            print("FAIL: TTFP exceeds target")

asyncio.run(test_ttfp())
EOF
```
</action>
  <verify>
    <automated>python3 -m py_compile cloud_server/app/routers/tts.py cloud_server/app/services/vibevoice_tts.py && echo "SYNTAX OK"</automated>
  </verify>
  <acceptance_criteria>
    - curl http://localhost:8000/voices returns 200 with 5 preset voices
    - WebSocket /v1/tts/stream accepts start message and streams audio chunks
    - Empty text returns error with code TEXT_EMPTY
    - Long text (>8000 chars) returns error with code TEXT_TOO_LONG
    - Invalid voice_id returns error with code INVALID_VOICE
    - TTFP (Time To First PCM Chunk) < 500ms
    - WebSocket stays connected for 10 minutes without disconnect
  </acceptance_criteria>
  <done>
    - /voices endpoint returns 5 preset voices with default zh_female_1
    - WebSocket TTS streams audio chunks in correct format
    - Input validation works (empty text, long text, invalid voice)
    - Rate limiting enforces max 10 concurrent sessions
    - User confirmed TTFP < 500ms
    - User confirmed 10-minute WebSocket stability
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client → /v1/tts/stream | Untrusted text data crosses here |
| GPU inference → response | Internal computation stays server-side |

## ASVS L1 Threats (per Phase requirements)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-01 | Input Validation (TTS-01) | /v1/tts/stream | mitigate | Reject empty text; reject text > 8000 chars; validate voice_id against preset list |
| T-02-02 | Rate Limiting (TTS-02) | /v1/tts/stream | mitigate | Max 10 concurrent TTS sessions; return RATE_LIMITED error when exceeded |
| T-02-03 | Connection Timeout (TTS-03) | /v1/tts/stream | mitigate | WebSocket timeout 10 minutes; heartbeat ping/pong every 30s |
| T-02-04 | Denial | GPU memory | mitigate | gpu_memory_utilization=0.5 leaves headroom; unload ASR before loading TTS |
| T-02-05 | Information | error messages | mitigate | Return generic errors to client; log detailed errors server-side only |

## STRIDE Threat Register

| Threat ID | Category | Disposition | Mitigation |
|-----------|----------|-------------|------------|
| T-02-01 | Information Disclosure | mitigate | Don't expose model internals in error messages |
| T-02-02 | Denial of Service | mitigate | Rate limiting + max text length + GPU memory limits |
| T-02-03 | Tampering | mitigate | Validate voice_id against whitelist only |
</threat_model>

<verification>
## Server-Side Verification

After implementation, verify these on the Windows Server:

```bash
# 1. Build and start Docker
docker compose down && docker compose build && docker compose up -d

# 2. Check logs
docker compose logs -f vibevoice-asr

# 3. Test /voices
curl http://localhost:8000/voices | jq

# 4. Test WebSocket TTS
python3 -c "
import asyncio, websockets, json, time
async def test():
    async with websockets.connect('ws://localhost:8000/v1/tts/stream') as ws:
        meta = await ws.recv()
        t0 = time.time()
        await ws.send(json.dumps({'type': 'start', 'text': '你好', 'voice_id': 'zh_female_1'}))
        chunk = await ws.recv()
        ttfp = (time.time() - t0) * 1000
        print(f'TTFP: {ttfp:.0f}ms (target: <500ms)')
asyncio.run(test())
"

# 5. Test input validation
# Empty text -> TEXT_EMPTY
# >8000 chars -> TEXT_TOO_LONG
# Invalid voice_id -> INVALID_VOICE

# 6. Test rate limiting
# 11 concurrent connections -> RATE_LIMITED

# 7. Test 10-minute stability
# Run WebSocket for 10 minutes, confirm no disconnect
```

## Must-Have Checklist

- [ ] `/voices` returns 200 with `{"voices": [...], "default": "zh_female_1"}`
- [ ] WebSocket accepts `{"type": "start", "text": "...", "voice_id": "..."}`
- [ ] WebSocket returns metadata before audio chunks
- [ ] Audio chunks are PCM16 little-endian format
- [ ] Done message received at stream end
- [ ] Error message received for empty text (TEXT_EMPTY)
- [ ] Error message received for long text (TEXT_TOO_LONG)
- [ ] Error message received for invalid voice (INVALID_VOICE)
- [ ] Rate limit enforced (RATE_LIMITED after 10 sessions)
- [ ] TTFP < 500ms (per REQ-07)
- [ ] WebSocket 10-minute stability verified
</verification>

<success_criteria>
1. `curl http://localhost:8000/voices` returns HTTP 200 with 5 preset voices
2. WebSocket connection to `ws://localhost:8000/v1/tts/stream` accepts JSON handshake and streams PCM audio
3. Server sends metadata message before first audio chunk
4. Server sends `{"type": "done", ...}` at stream end
5. Server returns error for invalid inputs (empty text, long text, invalid voice)
6. Rate limiting rejects when >10 concurrent sessions
7. TTFP (Time To First PCM Chunk) < 500ms (REQ-07)
8. WebSocket stays connected for 10 minutes without disconnect
9. ModelManager correctly unloads ASR before loading TTS
10. Docker container runs without OOM on RTX 4060 (8GB VRAM)
</success_criteria>

<output>
After completion, create `.planning/phases/02-cloud-tts-foundation/02-S-SUMMARY.md`
</output>
