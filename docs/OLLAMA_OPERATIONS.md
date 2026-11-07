# Ollama operations — Medveris supporting services

## Purpose

Ollama provides a local large-language-model runtime on the Kamatera VPS. It is
private infrastructure and is not intended for public exposure during initial
deployment.

## Network binding

Ollama listens on `127.0.0.1:11434` only.

The Compose file publishes that binding as `127.0.0.1:11434:11434`.

Do not change the binding to `0.0.0.0`.

## Persistence

Models and runtime state are stored in the Docker volume
`medveris_ollama_models`.

This volume is preserved across container restarts and normal deployment
lifecycle operations.

Do not delete it as part of routine deployment or rollback.

## Model management

Do not automatically download large models during deployment.

Pull models manually only when needed. When you do, consider:

- Disk space on the VPS
- Available RAM
- Model size relative to the 4 vCPU / 8 GB host

If model pulls fail or the service becomes unstable, inspect container logs
before restarting.

## Health checks

The Compose healthcheck runs `ollama list`.

If Ollama is unhealthy:

1. Check container logs.
2. Confirm the model storage volume is intact.
3. Restart only after understanding the failure.

## Usage notes

- Ollama is reachable from the VPS itself and from containers on the same
  Docker host/networking stack as configured.
- It is not a public HTTP service in this deployment.
- If an application needs to use Ollama, it should do so through the approved
  private path only.

## Security boundaries

- Do not expose port 11434 publicly.
- Do not place Ollama behind an unapproved reverse proxy.
- Do not open firewall access to 11434 without explicit approval.

## Resource expectations

Ollama can be resource-intensive. On a 4 vCPU / 8 GB VPS:

- Keep model choices appropriate to available memory.
- Avoid assuming every model will fit.
- Monitor host memory and disk usage after model operations.

## Updates

Ollama image tags are pinned in `docker/compose.yml`. Update the pin, validate
the compose file, and deploy from `main` through the workflow.
