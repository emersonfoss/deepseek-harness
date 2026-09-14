# Railway deploy: dsh web (experiment)

Self-hosts the DeepSeek Harness web UI on Railway behind an nginx basic-auth
reverse proxy.

## Why the proxy

`dsh web` intentionally refuses `--host 0.0.0.0` — the web UI executes
model-generated code on the host, so upstream binds to loopback only
(`packages/bundle/web-app/src/startup.ts`). Railway requires the service to
listen on a network interface, so nginx is the network-facing process and dsh
stays on `127.0.0.1:3080`.

## Variables

- `PORT` — injected by Railway; nginx listens here
- `WEB_USER` / `WEB_PASS` — basic-auth credentials (a random password is
  printed in the deploy logs when `WEB_PASS` is unset)
- `TRUSTED_HOST` — set to `${RAILWAY_PUBLIC_DOMAIN}` so dsh's `/api`
  browser-trust fence accepts requests arriving via the Railway domain

## Warnings

- Developer-preview software with no security audit that executes
  model-generated code (`SAFETY.md`). Treat the container as disposable.
- Container storage is ephemeral: sessions and plugins reset on redeploy.
  Mount a Railway volume if persistence matters.
- Do not remove the basic-auth layer or bake model API keys into the image.