# n8n Docker image configuration

# Allows changing the version of n8n at build time
ARG N8N_VERSION=2.8.1

# Use the official n8n image
FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}

# Cloud Run expects the default service to listen on PORT 8080 by convention,
# but n8n listens on 5678. We can leave it mapped externally or just configure
# the container to expose it. Cloud Run can map 8080 to any exposed port.
EXPOSE 5678

# Ensure we run as the non-root node user (n8n's uid is 1000)
USER node
