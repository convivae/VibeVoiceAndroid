from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.routers import asr, health


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: load ASR model into GPU
    from app.services.vibevoice_asr import asr_service
    await asr_service.load()
    yield
    # Shutdown: release resources
    await asr_service.unload()


app = FastAPI(
    title="VibeVoice-ASR Cloud Server",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(asr.router, prefix="/v1/asr", tags=["ASR"])
app.include_router(health.router, tags=["Health"])


@app.get("/")
async def root():
    return {"service": "VibeVoice-ASR", "version": "1.0.0"}