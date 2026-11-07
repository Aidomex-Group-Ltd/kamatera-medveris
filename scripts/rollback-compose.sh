#!/bin/bash
# Medveris supporting services — rollback script
#
# Usage:
#   scripts/rollback-compose.sh /opt/medveris/compose
#
# Safety rules:
#  - This script stops and removes containers and networks for the project.
#  - It does NOT delete persistent volumes.
#  - It does NOT delete the n8n or Ollama data stores.
#  - It does NOT change firewall, SSH, or native PostgreSQL configuration.
#
# If you need to restore a previous compose configuration, use the backup
# directory under /opt/medveris/compose/.deploy-backups/.

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

echo "Rolling back Compose project in $DEPLOY_DIR..."
echo "Stopping and removing containers/networks only. Volumes are preserved."

docker compose -f "$COMPOSE_FILE" --project-directory "$DEPLOY_DIR" down

echo
echo "Rollback complete."
echo "Persistent volumes are still present:"
docker volume ls --filter "name=medveris" --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"
