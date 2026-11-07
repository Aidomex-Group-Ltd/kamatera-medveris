# Ollama (supporting service)

This directory is intentionally lightweight. The service definition lives in
`../compose.yml` as the `ollama` service.

## Purpose
- Local large-language-model runtime for the Kamatera VPS.
- Private infrastructure only. Not a public HTTP service.

## Network binding
- Ollama listens on `127.0.0.1:11434` only.
- The Compose file publishes `127.0.0.1:11434:11434`.
- Do not change this binding to `0.0.0.0`.

## Persistence
- Models and state are stored in the Docker volume `medveris_ollama_models`.
- The volume is not deleted by normal Compose lifecycle commands.

## Model policy
- Do not automatically download large models during deployment.
- Pull models manually and only when needed, with awareness of disk and RAM.
- On a 4 vCPU / 8 GB VPS, keep resource expectations realistic.

## Health
- The Compose healthcheck runs `ollama list`.
- If Ollama is unhealthy, inspect container logs before restarting.

## Security reminders
- Do not expose port 11434 publicly.
- Do not add Ollama behind an unapproved reverse proxy or public DNS.
- Do not open firewall access to 11434 without explicit approval.
