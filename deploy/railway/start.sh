#!/bin/sh
# Boots dsh web on loopback (127.0.0.1:3080) and nginx with basic auth on $PORT.
set -e

: "${PORT:=8080}"
WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)}"

htpasswd -bc /etc/nginx/.htpasswd "$WEB_USER" "$WEB_PASS" >/dev/null
echo "=================================================="
echo " dsh web login -> user: $WEB_USER  pass: $WEB_PASS"
echo " (override via WEB_USER / WEB_PASS variables)"
echo "=================================================="

envsubst '${PORT}' < /app/nginx.conf.template > /etc/nginx/nginx.conf

# Wire a self-hosted (tunneled) model as a custom pi-ai provider when
# LOCAL_LLM_BASE_URL is set. Regenerated on every boot since container
# storage is ephemeral (see README.md). This path is only for a self-hosted
# endpoint with no vendor key -- never bake a real API key here.
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
mkdir -p "$DSH_HOME"
if [ -n "$LOCAL_LLM_BASE_URL" ]; then
  LOCAL_LLM_MODEL_ID="${LOCAL_LLM_MODEL_ID:-local-model}"
  LOCAL_LLM_MODEL_NAME="${LOCAL_LLM_MODEL_NAME:-Local model}"
  cat > "$DSH_HOME/settings.yaml" <<YAML
llm-pi-ai:
  providers:
    local-llm:
      displayName: Local LLM (tunnel)
      apiKeyEnv: LOCAL_LLM_API_KEY
      api: openai-completions
      baseURL: "$LOCAL_LLM_BASE_URL"
      compat:
        supportsDeveloperRole: false
        maxTokensField: max_tokens
      models:
        - id: "$LOCAL_LLM_MODEL_ID"
          name: "$LOCAL_LLM_MODEL_NAME"
YAML
  echo "Configured local-llm custom provider -> $LOCAL_LLM_BASE_URL"
fi

# TRUSTED_HOST lets dsh's /api browser-trust fence accept requests that arrive
# via the Railway public domain (set it to ${RAILWAY_PUBLIC_DOMAIN} in Railway).
DSH_ARGS="--host 127.0.0.1 --port 3080 --no-open"
if [ -n "$TRUSTED_HOST" ]; then
  DSH_ARGS="$DSH_ARGS --trusted-host $TRUSTED_HOST"
fi

dsh web $DSH_ARGS &
exec nginx -g "daemon off;"