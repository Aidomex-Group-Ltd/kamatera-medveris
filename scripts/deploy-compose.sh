#!/bin/bash
# Medveris supporting services — Compose deployment script
#
# Usage:
#   scripts/deploy-compose.sh deploy /opt/medveris/compose
#   scripts/deploy-compose.sh status /opt/medveris/compose
#
# This script operates only on the fixed Medveris Compose project directory.
# It does not accept arbitrary shell commands, arbitrary paths, or injected
# operations. It does not delete volumes and does not modify host network,
# firewall, SSH, or PostgreSQL configuration.

set -euo pipefail

ACTION="${1:-}"
DEPLOY_DIR="${2:-}"

if [ -z "$ACTION" ] || [ -z "$DEPLOY_DIR" ]; then
  echo "Usage: $0 deploy|status <deploy_dir>"
  exit 1
fi

# Only allow known actions.
case "$ACTION" in
  deploy|status)
    ;;
  *)
    echo "Error: unsupported action '$ACTION'"
    exit 1
    ;;
esac

# Fixed expected deployment layout.
COMPOSE_FILE="$DEPLOY_DIR/compose.yml"
ENV_FILE="$DEPLOY_DIR/.env"
REPO_COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/docker/compose.yml"
BACKUP_BASE="$DEPLOY_DIR/.deploy-backups"

if [ "$ACTION" = "deploy" ]; then
  if [ ! -f "$REPO_COMPOSE_FILE" ]; then
    echo "Error: compose file not found in repo at $REPO_COMPOSE_FILE"
    exit 1
  fi

  if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Error: deployment directory does not exist: $DEPLOY_DIR"
    exit 1
  fi

  # Validate repository compose configuration before touching the host.
  echo "Validating compose configuration..."
  if ! docker compose -f "$REPO_COMPOSE_FILE" config --quiet; then
    echo "Error: compose configuration is invalid"
    exit 1
  fi

  # Pre-deployment configuration backup. This preserves previous config files;
  # it does not delete volumes or data.
  mkdir -p "$BACKUP_BASE"
  TIMESTAMP="$(date +%Y%m%dT%H%M%S)"
  BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"

  if [ -f "$COMPOSE_FILE" ]; then
    cp -a "$COMPOSE_FILE" "$BACKUP_DIR/compose.yml"
  fi
  if [ -f "$ENV_FILE" ]; then
    cp -a "$ENV_FILE" "$BACKUP_DIR/.env"
  fi

  echo "Backing up existing configuration to $BACKUP_DIR"

  # Deploy the fixed compose project.
  echo "Deploying supporting services to $DEPLOY_DIR..."
  cp -a "$REPO_COMPOSE_FILE" "$COMPOSE_FILE"

  if [ -f "$ENV_FILE" ]; then
    echo "Using existing .env at $ENV_FILE"
  else
    echo "Warning: no .env found at $ENV_FILE; deployment may fail without required variables"
  fi

  docker compose -f "$COMPOSE_FILE" --project-directory "$DEPLOY_DIR" up -d --remove-orphans

  echo "Deployment complete."
  echo "Next: run verify against $DEPLOY_DIR"

elif [ "$ACTION" = "status" ]; then
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "No compose file found at $COMPOSE_FILE"
    exit 1
  fi

  echo "Compose project status for $DEPLOY_DIR:"
  docker compose -f "$COMPOSE_FILE" --project-directory "$DEPLOY_DIR" ps
  echo
  echo "Recent compose log tail (last 200 lines):"
  docker compose -f "$COMPOSE_FILE" --project-directory "$DEPLOY_DIR" logs --tail 200
fi
