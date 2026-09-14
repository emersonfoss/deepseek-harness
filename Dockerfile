# Railway deployment for the dsh web UI (self-hosted experiment).
#
# Upstream deliberately refuses `--host 0.0.0.0` because the web UI can execute
# model-generated code on the host ("would expose remote code execution to the
# network"). This image respects that: dsh web binds to loopback only, and an
# nginx reverse proxy with HTTP basic auth is the only network-facing process.
#
# Do not remove the basic auth layer, and do not bake API keys into this image.
# See deploy/railway/README.md.
FROM node:24-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx gettext-base apache2-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pinned: upstream is a developer preview with breaking changes between RCs.
RUN npm install -g @deepseek-ai/dsh@0.1.5-rc.2

WORKDIR /app
COPY deploy/railway/nginx.conf.template /app/nginx.conf.template
COPY deploy/railway/start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 8080
CMD ["/app/start.sh"]