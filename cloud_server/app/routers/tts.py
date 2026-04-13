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
from starlette.websockets import WebSocketState
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
