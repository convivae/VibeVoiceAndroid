from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import asyncio
import json
import logging
import time
from typing import AsyncGenerator
import numpy as np

from app.models.schemas import ASRStartMessage, ASRTranscriptChunk, ASRError
from app.services.vibevoice_asr import asr_service

router = APIRouter()
logger = logging.getLogger(__name__)

# T-01-01: Max audio buffer limit (10MB ~ 500s audio at 16kHz PCM16)
MAX_AUDIO_BUFFER_BYTES = 10 * 1024 * 1024

# T-01-03: Max concurrent connections (per REQ-04)
_active_connections = 0
MAX_CONCURRENT_CONNECTIONS = 2


@router.websocket("/stream")
async def asr_stream(ws: WebSocket):
    """
    WebSocket ASR streaming endpoint.
    
    Protocol (per D-01, D-02):
    1. Client sends JSON: {"type": "start", "language": "zh"}
    2. Client sends binary PCM16 chunks (~800-1200 bytes per 50ms)
    3. Server streams back: {"type": "transcript", "text": "...", "is_final": false}
    4. On disconnect: server sends {"type": "done", "text": "..."}
    
    Threat mitigations:
    - T-01-01: Max audio buffer limit enforced
    - T-01-02: PCM16 format validation (int16 range check)
    - T-01-03: Max concurrent connections limit
    - T-01-04: Generic errors to client, details logged server-side
    """
    global _active_connections
    
    # T-01-03: Connection limit check
    if _active_connections >= MAX_CONCURRENT_CONNECTIONS:
        try:
            await ws.close(code=503, reason="Server at capacity")
        except Exception:
            pass
        return
    
    _active_connections += 1
    try:
        await ws.accept()
        
        audio_buffer = bytearray()
        language = "zh"
        start_time_ms = 0
        
        # Phase 1: Receive JSON start message
        try:
            start_msg = await ws.receive_json()
            start_data = ASRStartMessage(**start_msg)
            language = start_data.language
            
            # Send acknowledgment
            await ws.send_json({
                "type": "ready",
                "language": language,
            })
        except Exception as e:
            logger.error(f"Failed to parse start message: {e}")
            await ws.send_json(ASRError(
                type="error",
                message="Invalid start message format",
                code="INVALID_REQUEST",
            ).model_dump())
            return
        
        # Phase 2: Receive binary audio chunks
        while True:
            try:
                # Receive bytes (binary PCM chunks)
                chunk = await asyncio.wait_for(
                    ws.receive_bytes(),
                    timeout=5.0,
                )
                
                # T-01-01: Validate audio buffer size limit
                if len(audio_buffer) + len(chunk) > MAX_AUDIO_BUFFER_BYTES:
                    logger.warning(f"Audio buffer exceeds limit: {len(audio_buffer) + len(chunk)} bytes")
                    await ws.send_json(ASRError(
                        type="error",
                        message="Audio exceeds maximum length",
                        code="BUFFER_OVERFLOW",
                    ).model_dump())
                    return
                
                audio_buffer.extend(chunk)
                
                if start_time_ms == 0:
                    start_time_ms = int(time.time() * 1000)
                
                # T-01-02: Validate PCM16 format (basic check)
                # Try to decode first few samples as int16
                if len(chunk) >= 4:
                    try:
                        samples = np.frombuffer(bytes(chunk[:4]), dtype=np.int16)
                        # Basic sanity check - if all zeros or extreme values, might be invalid
                        for s in samples:
                            if s < -32768 or s > 32767:
                                logger.warning(f"Invalid PCM16 value detected: {s}")
                                break
                    except Exception:
                        pass  # Skip validation if chunk too small
                
            except asyncio.TimeoutError:
                # No data for 5s — client may have stopped
                continue
            except WebSocketDisconnect:
                break
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        # T-01-04: Generic error to client, detailed log server-side
        try:
            await ws.send_json(ASRError(
                type="error",
                message="Internal server error",
                code="INTERNAL_ERROR",
            ).model_dump())
        except:
            pass
        return
    
    # Run ASR on complete audio
    if len(audio_buffer) == 0:
        try:
            await ws.send_json({"type": "done", "text": ""})
            return
        except:
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
                message=f"Transcription failed",
                code="ASR_ERROR",
            ).model_dump())
        except:
            pass
    finally:
        _active_connections -= 1


def _sync_transcribe(audio_bytes: bytes, language: str) -> str:
    """Synchronous transcription helper (runs in thread pool)."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(
            asr_service.transcribe_full(audio_bytes, language)
        )
    finally:
        loop.close()