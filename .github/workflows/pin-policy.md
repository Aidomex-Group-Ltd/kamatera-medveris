# Image pin policy for Medveris supporting services

The machine-readable policy lives in `.github/workflows/pin-policy.json`.
That file is what the deployment workflow actually checks.

## Purpose

- Every Compose image must be pinned.
- No `:latest`.
- Only allow-listed image name prefixes and tag patterns may be used.
- If an image includes an explicit registry component, that registry
  must be allow-listed.

## Registry handling

- Images with no `/` are treated as Docker Hub images.
- Images such as `ollama/ollama:` and `n8nio/n8n:` are also treated
  as Docker Hub images for registry purposes.
- Only images with an explicit non-Docker-Hub registry component are
  checked against `allowed_registries`.

## Image prefix matching

The workflow checks that the image name, before the tag, starts with an
allow-listed prefix. Current allow-listed prefixes:

- `ollama/ollama`
- `n8nio/n8n`
- `postgres`

## Why this is strict

The deployment workflow runs on a self-hosted Kamatera runner, so image
provenance should be explicit.

## Updating pins

1. Choose the new pinned tag.
2. Update `docker/compose.yml`.
3. If the new image is from an already-allow-listed registry and prefix,
   the workflow should still pass. If not, update
   `.github/workflows/pin-policy.json` first and review it.
4. Validate `docker compose config` locally or in CI.
5. Commit and push to `main`, then deploy via `workflow_dispatch`.

Never relax this policy to permit `:latest` or arbitrary registries.
