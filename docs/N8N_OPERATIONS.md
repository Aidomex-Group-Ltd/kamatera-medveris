# n8n operations — Medveris supporting services

## Purpose

n8n is a workflow automation runtime hosted on the Kamatera VPS as supporting
infrastructure.

## Database

n8n uses its own dedicated PostgreSQL container defined in
`docker/compose.yml` as `n8n-postgres`.

Important constraints:

- n8n must not use the native Kamatera PostgreSQL 18.6 cluster.
- The n8n database container is on the private Docker network
  `medveris_internal`.
- Port 5432 is not published.
- Do not create n8n roles or databases in the native PostgreSQL cluster.

## Persistence

n8n configuration, credentials, and workflow state are persisted in the n8n
PostgreSQL volume `medveris_n8n_postgres_data`.

This volume is preserved across restarts and normal deployment lifecycle
operations.

Do not delete it during routine deployment or rollback.

## Encryption key

n8n uses `N8N_ENCRYPTION_KEY` for credential encryption at rest.

Operational rules:

- Generate the key once on the VPS with a secure random source.
- Store it in `/opt/medveris/compose/.env` with restrictive permissions.
- Treat it as a persistent secret.
- Losing the key can make n8n credential encryption unrecoverable.
- Do not rotate it arbitrarily.

## Network binding

n8n listens on `127.0.0.1:5678` only.

The Compose file publishes that binding as `127.0.0.1:5678:5678`.

Do not publish 5678 publicly without explicit approval.

## Protocol and webhook URLs

The Compose file sets:

- `N8N_PROTOCOL=http`
- `WEBHOOK_URL=http://n8n.internal:5678`

These are internal defaults. If n8n is later exposed through an approved reverse
proxy or public hostname, update these values before exposing it.

During initial deployment, n8n remains private.

## Health checks

The Compose healthcheck polls `http://127.0.0.1:5678/health`.

If n8n is unhealthy:

1. Check the n8n container logs.
2. Check the n8n PostgreSQL container logs.
3. Confirm the database connection parameters in `.env`.
4. Restart only after understanding the failure.

## Security boundaries

- Do not expose port 5678 publicly without explicit approval.
- Do not open firewall access to 5678 without explicit approval.
- Do not rewrite n8n credentials or workflows through unapproved channels.
- Do not use the native PostgreSQL 18.6 cluster for n8n unless separately
  approved.

## Updates

n8n image tags are pinned in `docker/compose.yml`. Update the pin, validate the
compose file, and deploy from `main` through the workflow.
