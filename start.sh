#!/bin/sh

# Create the state directory so Tailscale doesn't throw a missing folder warning
mkdir -p /var/lib/tailscale

echo "Starting Tailscale daemon in userspace mode..."
# Run tailscaled in the background with userspace networking
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &

# Give the daemon 5 seconds to initialize
sleep 5

# Authenticate Tailscale
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Authenticating Tailscale node..."
    # Using --accept-dns=false ensures we don't break SearXNG's internal routing
    tailscale up --authkey="${TAILSCALE_AUTHKEY}" --ssh --hostname=render-searxng --accept-dns=false
else
    echo "CRITICAL ERROR: TAILSCALE_AUTHKEY environment variable is missing!"
    exit 1
fi

echo "Running native SearXNG boot sequence..."
# Execute the original SearXNG entrypoint to start the application
exec /usr/local/searxng/dockerfiles/docker-entrypoint.sh
