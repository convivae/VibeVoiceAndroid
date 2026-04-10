from pydantic import BaseModel, Field
from typing import Literal, Optional, List


class ASRStartMessage(BaseModel):
    """Client sends this as first JSON message on WebSocket"""
    type: Literal["start"]
    language: str = "zh"  # "zh" = Mandarin (default), "en" = English


class ASRTranscriptChunk(BaseModel):
    """Server streams these back during transcription"""
    type: Literal["transcript"] = "transcript"
    text: str
    is_final: bool
    timestamp_ms: int


class ASRFinal(BaseModel):
    """Server sends on WebSocket disconnect"""
    type: Literal["done"]
    text: str


class ASRError(BaseModel):
    """Server sends on error"""
    type: Literal["error"]
    message: str
    code: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model: str
    device: str


# =============================================================================
# TTS Schemas (Phase 2 - Cloud TTS Foundation)
# =============================================================================

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
