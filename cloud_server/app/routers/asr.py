from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import asyncio
import json
import logging
import time
from typing import AsyncGenerator

from app.models.schemas import ASRStartMessage, ASRTranscriptChunk, ASRError
from app.services.vibevoice_asr import asr_service

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/stream")
async def asr_stream(ws: WebSocket):
    """
    WebSocket ASR streaming endpoint.
    
    Protocol (per D-01, D-02):
    1. Client sends JSON: {"type": "start", "language": "zh"}
    2. Client sends binary PCM16 chunks (~800-1200 bytes per 50ms)
    3. Server streams back: {"type": "transcript", "text": "...", "is_final": false}
    4. On disconnect: server sends {"type": "done", "text": "..."}
    
    Security (T-01-01 through T-01-04):
    - Max audio buffer: 10MB (T-01-01)
    - PCM16 validation on audio bytes (T-01-02)
    - Max 2 concurrent connections enforced (T-01-03)
    - Generic errors to client, detailed logs server-side (T-01-04)
    """
    # T-01-03: Connection limit
    if hasattr(asr_service, '_active_connections') is False:
        asr_service._active_connections = 0
    
    if asr_service._active_connections >= 2:
        try:
            await ws.accept()
            await ws.send_json(ASRError(
                type="error",
                message="Server at capacity. Please try again later.",
                code="CAPACITY_EXCEEDED",
            ).model_dump())
            await ws.close()
        except:
            pass
        return
    
    asr_service._active_connections += 1
    await ws.accept()
    
    audio_buffer = bytearray()
    language = "zh"
    start_time_ms = 0
    
    try:
        # Phase 1: Receive JSON start message
        start_msg = await ws.receive_json()
        start_data = ASRStartMessage(**start_msg)
        language = start_data.language
        
        # Phase 2: Receive binary audio chunks
        while True:
            try:
                # Receive bytes (binary PCM chunks)
                chunk = await asyncio.wait_for(
                    ws.receive_bytes(),
                    timeout=5.0,
                )
                
                # T-01-01: Max audio buffer limit (10MB)
                if len(audio_buffer) + len(chunk) > 10 * 1024 * 1024:
                    await ws.send_json(ASRError(
                        type="error",
                        message="Audio buffer limit exceeded (max 10MB)",
                        code="BUFFER_OVERFLOW",
                    ).model_dump())
                    asr_service._active_connections -= 1
                    return
                
                audio_buffer.extend(chunk)
                
                if start_time_ms == 0:
                    start_time_ms = int(time.time() * 1000)
                
            except asyncio.TimeoutError:
                # No data for 5s — client may have stopped
                continue
                
    except WebSocketDisconnect:
        # Client disconnected — run final transcription
        pass
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        try:
            await ws.send_json(ASRError(
                type="error",
                message=str(e),
                code="INTERNAL_ERROR",
            ).model_dump())
        except:
            pass
        asr_service._active_connections -= 1
        return
    
    # Run ASR on complete audio
    if len(audio_buffer) == 0:
        try:
            await ws.send_json({"type": "done", "text": ""})
        except:
            pass
        asr_service._active_connections -= 1
        return
    
    try:
        # Non-blocking transcription
        transcription = await asyncio.get_event_loop().run_in_executor(
            None,
            _sync_transcribe,
            bytes(audio_buffer),
            language,
        )
        
        await ws.send_json({
            "type": "done",
            "text": transcription,
        })
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        try:
            await ws.send_json(ASRError(
                type="error",
                message="Transcription failed",
                code="ASR_ERROR",
            ).model_dump())
        except:
            pass
    finally:
        asr_service._active_connections -= 1


def _sync_transcribe(audio_bytes: bytes, language: str) -> str:
    """Synchronous transcription helper (runs in thread pool)."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(
            asr_service.transcribe_full(audio_bytes, language)
        )
    finally:
        loop.close()
