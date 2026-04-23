#!/bin/sh

# 1. Setup Tailscale
mkdir -p /var/lib/tailscale /var/run/tailscale

echo "Starting Tailscale daemon in userspace mode..."
# Removed the SOCKS5 server flag to stop Render's health checks from triggering log spam
/usr/local/bin/tailscaled --tun=userspace-networking &

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
(cd /tmp/dummy_web && python3 -m http.server ${PORT:-10000}) &

# 4. Bind SearXNG to 0.0.0.0 so Tailscale can correctly route to it
# Note: This is SAFE. Render ONLY exposes the $PORT (10000) to the public internet.
# Port 8080 remains completely inaccessible from the outside, but Tailscale can reach it locally!
export SEARXNG_BIND_ADDRESS="0.0.0.0"
export GRANIAN_ADDRESS="0.0.0.0"
export SEARXNG_PORT="8080"
export GRANIAN_PORT="8080"

# 5. Dynamically locate and execute the native SearXNG boot sequence
echo "Locating native SearXNG entrypoint..."
SEARXNG_ENTRYPOINT=$(find / -type f \( -name "docker-entrypoint.sh" -o -name "entrypoint.sh" \) 2>/dev/null | grep -i "searx" | head -n 1)

if [ -z "$SEARXNG_ENTRYPOINT" ]; then
    SEARXNG_ENTRYPOINT=$(find /usr -type f -name "entrypoint.sh" 2>/dev/null | head -n 1)
fi

if [ -n "$SEARXNG_ENTRYPOINT" ]; then
    echo "Found entrypoint at $SEARXNG_ENTRYPOINT. Handing over execution!"
    exec "$SEARXNG_ENTRYPOINT"
else
    echo "CRITICAL ERROR: Could not find SearXNG entrypoint script."
    exit 1
fi
