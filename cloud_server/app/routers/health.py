from fastapi import APIRouter
from app.models.schemas import HealthResponse
from app.services.vibevoice_asr import asr_service

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for container orchestration."""
    return HealthResponse(
        status="healthy" if asr_service._is_loaded else "starting",
        model_loaded=asr_service._is_loaded,
        model="microsoft/VibeVoice-ASR",
        device="cuda" if asr_service.device == "cuda" else "cpu",
    )
