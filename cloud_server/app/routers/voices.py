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
