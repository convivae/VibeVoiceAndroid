---
phase: 01-cloud-asr-pipeline
plan: 01
subsystem: infra
tags: [fastapi, uvicorn, transformers, torch, websocket, docker, gpu]

# Dependency graph
requires: []
provides:
  - FastAPI cloud ASR server with WebSocket streaming endpoint
  - Dockerfile with nvidia/cuda GPU container
  - docker-compose.yml with GPU passthrough orchestration
  - VibeVoice-ASR transformers-based inference service
  - Pydantic models for all WebSocket message types
affects: [02-cloud-tts-pipeline, 03-ondevice-asr]

# Tech tracking
tech-stack:
  added: [fastapi, uvicorn, pydantic, transformers, accelerate, torch, scipy, numpy]
  patterns: [async-context-manager-lifespan, websocket-streaming, thread-pool-executor, gpu-inference]

key-files:
  created:
    - cloud_server/requirements.txt
    - cloud_server/Dockerfile
    - cloud_server/docker-compose.yml
    - cloud_server/app/main.py
    - cloud_server/app/models/schemas.py
    - cloud_server/app/services/vibevoice_asr.py
    - cloud_server/app/routers/asr.py
    - cloud_server/app/routers/health.py

key-decisions:
  - "Used transformers fallback instead of vLLM plugin (vLLM plugin is batch-only, not streaming-capable per RESEARCH.md §4)"
  - "Implemented non-blocking transcription via thread pool executor (asyncio.get_event_loop().run_in_executor)"
  - "Enforced all 4 threat mitigations inline: max buffer 10MB, PCM16 validation, max 2 concurrent connections, generic errors to client"

patterns-established:
  - "Pattern: FastAPI lifespan context manager for GPU model load/unload lifecycle"
  - "Pattern: Global service singleton (asr_service) shared across WebSocket connections"
  - "Pattern: WebSocket disconnection = end-of-speech trigger for final transcription"

requirements-completed: [REQ-02, REQ-04]

# Metrics
duration: 8min
started: 2026-04-09T15:32:12Z
completed: 2026-04-09T15:40:27Z
tasks: 3
files_modified: 8
---

# Phase 1 Plan 1: Cloud ASR Server Summary

**FastAPI WebSocket服务器，使用transformers进行VibeVoice-ASR流式推理，含GPU容器化部署配置和4个威胁缓解措施**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-09T15:32:12Z
- **Completed:** 2026-04-09T15:40:27Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- 云服务器项目脚手架完整创建（requirements.txt、FastAPI入口、Dockerfile、docker-compose.yml）
- VibeVoice-ASR推理服务封装（transformers直接推理，bf16 GPU，异步load/unload）
- 完整Pydantic消息模型（ASRStartMessage、ASRTranscriptChunk、ASRFinal、ASRError、HealthResponse）
- FastAPI WebSocket流式端点 `/v1/asr/stream`（JSON握手+二进制PCM16 chunks，断开后完整转写）
- 健康检查端点 `/health`（返回model_loaded状态）
- 威胁缓解：T-01-01~T-01-04全部内联实现（缓冲区限制、格式验证、连接数上限、错误脱敏）

## Task Commits

1. **Task 1: 创建云服务器项目脚手架** - `8c06d2c` (feat)
2. **Task 2: 实现 Pydantic Schemas 和 ASR Service** - `20530eb` (feat)
3. **Task 3: 创建 FastAPI 路由** - `33ed0ff` (feat)

## Files Created/Modified

- `cloud_server/requirements.txt` - Python依赖（fastapi, uvicorn, transformers, torch等）
- `cloud_server/Dockerfile` - nvidia/cuda:12.4.1 GPU容器镜像
- `cloud_server/docker-compose.yml` - GPU passthrough编排配置
- `cloud_server/app/main.py` - FastAPI应用入口，CORS中间件，lifespan管理
- `cloud_server/app/models/schemas.py` - 所有WebSocket消息的Pydantic模型
- `cloud_server/app/services/vibevoice_asr.py` - VibeVoice-ASR transformers推理服务
- `cloud_server/app/routers/asr.py` - WebSocket ASR流式端点（threat mitigations内联）
- `cloud_server/app/routers/health.py` - 健康检查端点

## Decisions Made

- 使用transformers直接推理（而非vLLM plugin）——vLLM plugin为批处理设计，不支持实时流式推理（per RESEARCH.md §4）
- 推理在线程池执行器中运行（`asyncio.get_event_loop().run_in_executor`）——避免阻塞事件循环
- 全局`asr_service`单例——跨WebSocket连接共享已加载模型，避免重复VRAM占用

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

**External services require manual configuration.** This plan builds the cloud ASR server. The WSL2 GPU validation and Docker deployment must be performed on the Windows Server machine.

### WSL2 GPU Validation (Task 3B - Human Action Required)

These commands must be run on the **Windows Server WSL2 machine**:

```bash
# 1. Verify GPU passthrough
nvidia-smi
# Expected: Shows RTX 4060 GPU info with GPU-Util, Memory-Usage

# 2. Test CUDA
python3 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"

# 3. Build and start Docker container
cd cloud_server
docker compose up --build -d

# 4. Check logs
docker compose logs -f vibevoice-asr

# 5. Test health endpoint
curl http://localhost:8000/health
# Expected: {"status": "healthy", "model_loaded": true, ...}

# 6. End-to-end ASR test
# Convert any short audio to 16kHz mono PCM16:
ffmpeg -i test.wav -ar 16000 -ac 1 -f s16le test.pcm
# Send to server via WebSocket client (e.g., wscat):
wscat -c ws://localhost:8000/v1/asr/stream -x '{"type":"start","language":"zh"}' --binary
# Then pipe PCM data and check response
```

If `nvidia-smi` fails: WSL2 GPU passthrough not working. Fix: Install CUDA driver on Windows host (not in WSL2), then restart WSL2.

If model fails to load: Check VRAM (RTX 4060 = 8GB, FP16 needs ~14GB). Model must be INT4 quantized first.

## Next Phase Readiness

- Cloud ASR server code complete. Ready for:
  - Model quantization (INT4 AWQ for RTX 4060 8GB VRAM compatibility)
  - Flutter App integration (Plan 01-02)
- Dockerfile and docker-compose.yml ready for deployment to Windows Server WSL2

---
*Phase: 01-cloud-asr-pipeline*
*Completed: 2026-04-09*
