# Railway deployment for the dsh web UI (self-hosted experiment).
#
# Upstream deliberately refuses `--host 0.0.0.0` because the web UI can execute
# model-generated code on the host ("would expose remote code execution to the
# network"). This image respects that: dsh web binds to loopback only, and an
# nginx reverse proxy with HTTP basic auth is the only network-facing process.
#
# Do not remove the basic auth layer, and do not bake API keys into this image.
# See deploy/railway/README.md.
#
# Built from source with the default (non-"official") client profile instead
# of `npm install -g @deepseek-ai/dsh`: `pnpm run build` (as opposed to
# `pnpm run build:official`) is upstream's own supported path for a
# self-hosted identity -- it leaves DSH_CLIENT_BUILD_PROFILE unset, so
# @deepseek-ai/dsh-client-ui-brand-official never registers the whale mark or
# "DeepSeek Harness" wordmark in the sidebar, and the title falls back to a
# neutral "local build" label instead of DSH_CLIENT_TITLE. See
# packages/client/ui-brand-official/README.md and scripts/client-build-environment.ts.
FROM node:24-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 make g++ ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@11.7.0 --activate

WORKDIR /build
COPY . .
RUN pnpm install --frozen-lockfile
# .git is excluded from the build context (.dockerignore); the build script's
# commit-hash lookup falls back to `git rev-parse HEAD` only when this is unset.
ENV DSH_CLIENT_COMMIT_HASH=0000000
# Default profile (no --profile official): drops DeepSeek's own branding.
RUN pnpm run build

FROM node:24-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx gettext-base apache2-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
COPY --from=build /build /dsh-src

WORKDIR /app
COPY deploy/railway/nginx.conf.template /app/nginx.conf.template
COPY deploy/railway/start.sh /app/start.sh
COPY deploy/railway/skills /app/skills
RUN chmod +x /app/start.sh

EXPOSE 8080
CMD ["/app/start.sh"]
