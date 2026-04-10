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
