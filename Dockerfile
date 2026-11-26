FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/data/home \
    HF_HOME=/data/huggingface \
    TORCH_HOME=/data/torch

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY src ./src

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cpu torch torchvision \
    && python -m pip install --no-cache-dir ".[web]" \
    && python -m pip check \
    && groupadd --system --gid 10001 docfinder \
    && useradd --system --uid 10001 --gid docfinder --home-dir /data/home docfinder \
    && mkdir -p /data/home /data/huggingface /data/torch \
    && chown -R docfinder:docfinder /data

USER docfinder

VOLUME ["/data"]
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/', timeout=3).close()" || exit 1

CMD ["docfinder", "web", "--host", "0.0.0.0", "--port", "8000", "--db", "/data/docfinder.db"]
