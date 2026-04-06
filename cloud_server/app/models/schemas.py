from pydantic import BaseModel
from typing import Literal, Optional


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
