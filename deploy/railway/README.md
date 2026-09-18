# Railway deploy: dsh web (experiment)

Self-hosts the dsh web UI on Railway behind an nginx basic-auth reverse
proxy.

## Branding

The image builds dsh from source (`pnpm install && pnpm run build`) instead
of installing the published `@deepseek-ai/dsh` npm package. Upstream's own
build has two profiles: `build:official` (DeepSeek's branded release) and the
default `build` (no `--profile official`), which leaves
`DSH_CLIENT_BUILD_PROFILE` unset. `@deepseek-ai/dsh-client-ui-brand-official`
only registers the whale mark and "DeepSeek Harness" wordmark when that
profile is exactly `official` (`packages/client/ui-brand-official/README.md`),
so the default build ships the shell's neutral fallback mark and a
"local build" title instead — this is upstream's documented, supported path
for a self-hosted identity, not a patch. `apps/web/public/favicon.svg` was
also swapped for a neutral mark. `start.sh` runs the built source
(`pnpm dsh web` from `/dsh-src`) rather than a globally installed `dsh`
binary.

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
- `LOCAL_LLM_BASE_URL` — optional. When set, `start.sh` registers a custom
  `local-llm` pi-ai provider pointed at this OpenAI-compatible base URL (e.g.
  a tunnel such as `cloudflared tunnel --url http://127.0.0.1:PORT` fronting a
  self-hosted model like `mlx_lm.server`). Include the `/v1` suffix if the
  endpoint expects it.
- `LOCAL_LLM_API_KEY` — credential value read by the `local-llm` provider.
  The tunneled server need not actually enforce it; any non-empty value
  satisfies dsh's credential check.
- `LOCAL_LLM_MODEL_ID` / `LOCAL_LLM_MODEL_NAME` — optional, override the
  advertised model id/display name for the `local-llm` provider.

## Skills

`deploy/railway/skills/` is a vendored bundle of `<name>/SKILL.md` folders,
baked into the image at `/app/skills` (Dockerfile `COPY`) and registered on
every boot via `skill-filesystem.customSkillDirs` in `settings.yaml`, so
skills survive the container's ephemeral storage without a runtime git
clone. Sources: `emersonfoss/lq-skills` (legal skills), `emersonfoss/book-to-skill`,
`anthropics/skills` (official document/dev skills; its own `skill-creator`
was dropped in favor of lq-skills' version to avoid a name collision), and
`JayRHa/AgentSkills` (community engineering/devops/productivity skills). To
add or update skills, drop more `<name>/SKILL.md` folders into
`deploy/railway/skills/` and redeploy.

## Warnings

- Developer-preview software with no security audit that executes
  model-generated code (`SAFETY.md`). Treat the container as disposable.
- Container storage is ephemeral: sessions and plugins reset on redeploy.
  Mount a Railway volume if persistence matters.
- Do not remove the basic-auth layer or bake model API keys into the image.