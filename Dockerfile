# Stage 1: Pull the official Tailscale image to extract the binaries
FROM tailscale/tailscale:latest AS tailscale

# Stage 2: Build the final SearXNG image
FROM searxng/searxng:latest

# Switch to root to configure the environment
USER root

# Copy the tailscale binaries from Stage 1 directly into the SearXNG image
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Ensure Tailscale state directories exist
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Copy the custom initialization script
COPY start.sh /custom-start.sh
RUN chmod +x /custom-start.sh

# Expose port 8080 for SearXNG
EXPOSE 8080

# Override the default entrypoint to run our script first
ENTRYPOINT ["/custom-start.sh"]
