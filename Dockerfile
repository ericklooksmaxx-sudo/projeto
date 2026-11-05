# Production Dockerfile for Hollow Logger
FROM python:3.11-slim

# Prevent Python from writing .pyc files & enable unbuffered stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    HOST=0.0.0.0

WORKDIR /app

# Install system dependencies (curl, ca-certificates, procps)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    procps \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install lune (for Luau script analysis/execution)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -fsSL https://github.com/lune-org/lune/releases/download/v0.11.1/lune-0.11.1-linux-x86_64.zip -o lune.zip && \
        unzip lune.zip -d /usr/local/bin && chmod +x /usr/local/bin/lune && rm lune.zip; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -fsSL https://github.com/lune-org/lune/releases/download/v0.11.1/lune-0.11.1-linux-aarch64.zip -o lune.zip && \
        unzip lune.zip -d /usr/local/bin && chmod +x /usr/local/bin/lune && rm lune.zip; \
    fi || true

# Install darklua (for Lua formatting and minification)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -fsSL https://github.com/seaofvoices/darklua/releases/download/v0.19.0/darklua-linux-x86_64.zip -o darklua.zip && \
        unzip darklua.zip -d /usr/local/bin && chmod +x /usr/local/bin/darklua && rm darklua.zip; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -fsSL https://github.com/seaofvoices/darklua/releases/download/v0.19.0/darklua-linux-aarch64.zip -o darklua.zip && \
        unzip darklua.zip -d /usr/local/bin && chmod +x /usr/local/bin/darklua && rm darklua.zip; \
    fi || true

# Install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Ensure storage directories exist
RUN mkdir -p data dumps/original dumps/dumped dumps/errors

# Expose web health check port
EXPOSE 8080

# Run bot
CMD ["python3", "run.py"]
