#!/bin/bash
# Medveris supporting services — verification script
#
# Usage:
#   scripts/verify-services.sh /opt/medveris/compose
#
# This script verifies the deployed Compose project without publishing or
# probing public services and without deleting volumes.

set -euo pipefail

DEPLOY_DIR="${1:-}"

if [ -z "$DEPLOY_DIR" ]; then
  echo "Usage: $0 <deploy_dir>"
  exit 1
fi

COMPOSE_FILE="$DEPLOY_DIR/compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Error: compose file not found at $COMPOSE_FILE"
  exit 1
fi

echo "=== Compose project status ==="
docker compose -f "$COMPOSE_FILE" --project-directory "$DEPLOY_DIR" ps

echo
echo "=== Container health summary ==="
docker ps --filter "label=compose.project=medveris" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true

echo
echo "=== Persistent volumes ==="
docker volume ls --filter "name=medveris" --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"

echo
echo "=== Localhost-only port bindings ==="
if command -v ss >/dev/null 2>&1; then
  echo "Listening sockets (TCP):"
  ss -tlnp 2>/dev/null | grep -E ':(11434|5678|5432)\b' || echo "No matching listening sockets found"
else
  echo "ss not available; skipping socket inspection"
fi

echo
echo "=== Ollama localhost binding check ==="
if docker ps --filter "name=medveris-ollama" --format '{{.Names}}' | grep -q .; then
  OLAMA_PORTS="$(docker port medveris-ollama 2>/dev/null || true)"
  echo "Ollama published ports: $OLAMA_PORTS"
  if echo "$OLAMA_PORTS" | grep -E '0\.0\.0\.0:11434|:::*:11434' >/dev/null; then
    echo "Error: Ollama appears to be exposed publicly"
    exit 1
  fi
else
  echo "Ollama container not running"
fi

echo
echo "=== n8n localhost binding check ==="
if docker ps --filter "name=medveris-n8n" --format '{{.Names}}' | grep -q .; then
  N8N_PORTS="$(docker port medveris-n8n 2>/dev/null || true)"
  echo "n8n published ports: $N8N_PORTS"
  if echo "$N8N_PORTS" | grep -E '0\.0\.0\.0:5678|:::*:5678' >/dev/null; then
    echo "Error: n8n appears to be exposed publicly"
    exit 1
  fi
else
  echo "n8n container not running"
fi

echo
echo "=== n8n database container check ==="
if docker ps --filter "name=medveris-n8n-postgres" --format '{{.Names}}' | grep -q .; then
  echo "n8n PostgreSQL container is running"
else
  echo "n8n PostgreSQL container not running"
fi

echo
echo "=== Native PostgreSQL note ==="
echo "This script does not manage the native Kamatera PostgreSQL 18.6 cluster."
echo "Verify it separately with the host administrator if needed."

echo
echo "Verification complete."
