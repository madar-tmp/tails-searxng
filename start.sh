#!/bin/sh

# 1. Setup Tailscale
mkdir -p /var/lib/tailscale /var/run/tailscale

echo "Starting Tailscale daemon in userspace mode..."
/usr/local/bin/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &

# Give the daemon 5 seconds to initialize
sleep 5

# 2. Authenticate Tailscale (with SSH enabled)
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Authenticating Tailscale node..."
    /usr/local/bin/tailscale up --authkey="${TAILSCALE_AUTHKEY}" --ssh --hostname=render-searxng --accept-dns=false
else
    echo "CRITICAL ERROR: TAILSCALE_AUTHKEY environment variable is missing!"
    exit 1
fi

# 3. Handle Render Health Checks (Public Router)
echo "Securing instance: Starting dummy server for Render, isolating SearXNG to Tailscale..."
mkdir -p /tmp/dummy_web
echo "<html><body><h1>Private Tailscale Instance</h1><p>Access via Tailnet only.</p></body></html>" > /tmp/dummy_web/index.html

# We run a dummy web server in the background on Render's expected port. 
# This satisfies Render's health checks so the container isn't killed, but exposes no SearXNG data.
(cd /tmp/dummy_web && python3 -m http.server ${PORT:-10000}) &

# 4. Lock SearXNG to Localhost (Private)
# Forcing the bind address to 127.0.0.1 means the public internet CANNOT reach it.
export SEARXNG_BIND_ADDRESS="127.0.0.1"
export GRANIAN_ADDRESS="127.0.0.1"
export SEARXNG_PORT="8080"
export GRANIAN_PORT="8080"

# 5. Dynamically locate and execute the native SearXNG boot sequence
echo "Locating native SearXNG entrypoint..."
SEARXNG_ENTRYPOINT=$(find / -type f \( -name "docker-entrypoint.sh" -o -name "entrypoint.sh" \) 2>/dev/null | grep -i "searx" | head -n 1)

if [ -z "$SEARXNG_ENTRYPOINT" ]; then
    # Fallback if the above search misses
    SEARXNG_ENTRYPOINT=$(find /usr -type f -name "entrypoint.sh" 2>/dev/null | head -n 1)
fi

if [ -n "$SEARXNG_ENTRYPOINT" ]; then
    echo "Found entrypoint at $SEARXNG_ENTRYPOINT. Handing over execution!"
    exec "$SEARXNG_ENTRYPOINT"
else
    echo "CRITICAL ERROR: Could not find SearXNG entrypoint script."
    exit 1
fi
