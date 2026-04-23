# Stage 1: Pull the official Tailscale image to extract the binaries
FROM tailscale/tailscale:latest AS tailscale

# Stage 2: Build the final Debian-based image
FROM debian:bullseye-slim

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install your requested apps + SearXNG Python build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    procps \
    tmux \
    neofetch \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    build-essential \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the Tailscale binaries directly into the image
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Ensure Tailscale state directories exist
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# 3. Clone and install SearXNG from source
WORKDIR /usr/local/searxng
RUN git clone https://github.com/searxng/searxng.git . \
    && pip3 install --no-cache-dir -U pip setuptools wheel \
    && pip3 install --no-cache-dir -e .

# 4. Set required SearXNG environment variables
ENV SEARXNG_PORT=8080
ENV SEARXNG_BIND_ADDRESS=0.0.0.0
ENV SEARXNG_SETTINGS_PATH=/usr/local/searxng/searx/settings.yml

# 5. Copy the custom initialization script
COPY start.sh /custom-start.sh
RUN chmod +x /custom-start.sh

# Expose Render's default health check port
EXPOSE 10000

# Override the default entrypoint to run our script first
ENTRYPOINT ["/custom-start.sh"]
