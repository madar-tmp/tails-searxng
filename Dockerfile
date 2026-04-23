FROM searxng/searxng:latest

# Switch to root to install packages and run the Tailscale daemon
USER root

# SearXNG uses Alpine Linux; install tailscale
RUN apk update && apk add --no-cache tailscale

# Copy the custom initialization script
COPY start.sh /custom-start.sh
RUN chmod +x /custom-start.sh

# Expose port 8080 for SearXNG (Render uses this for health checks)
EXPOSE 8080

# Override the default entrypoint to run our script first
ENTRYPOINT ["/custom-start.sh"]
