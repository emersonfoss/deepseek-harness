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

# TRUSTED_HOST lets dsh's /api browser-trust fence accept requests that arrive
# via the Railway public domain (set it to ${RAILWAY_PUBLIC_DOMAIN} in Railway).
DSH_ARGS="--host 127.0.0.1 --port 3080 --no-open"
if [ -n "$TRUSTED_HOST" ]; then
  DSH_ARGS="$DSH_ARGS --trusted-host $TRUSTED_HOST"
fi

dsh web $DSH_ARGS &
exec nginx -g "daemon off;"