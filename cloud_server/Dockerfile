FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

WORKDIR /app

# Install Python + deps
RUN apt-get update && apt-get install -y \
    python3.11 python3-pip python3.11-venv \
    libsndfile1 ffmpeg git curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Clone VibeVoice model code
RUN git clone https://github.com/microsoft/VibeVoice /tmp/VibeVoice && \
    pip3 install --no-cache-dir /tmp/VibeVoice && \
    rm -rf /tmp/VibeVoice

COPY app/ /app/app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
