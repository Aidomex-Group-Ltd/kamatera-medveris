# n8n (supporting service)

This directory is intentionally lightweight. The service definitions live in
`../compose.yml` as the `n8n` and `n8n-postgres` services.

## Purpose
- Workflow automation runtime for the Kamatera VPS.
- Runs with its own dedicated PostgreSQL container.

## Database
- n8n uses the Compose service `n8n-postgres`, not the native Kamatera
  PostgreSQL 18.6 cluster.
- The n8n database container is on the private Docker network `medveris_internal`.
- Port 5432 is not published to the host.

## Network binding
- n8n listens on `127.0.0.1:5678` only.
- The Compose file publishes `127.0.0.1:5678:5678`.
- Do not publish 5678 publicly without explicit approval.

## Encryption key
- n8n uses `N8N_ENCRYPTION_KEY` for credential encryption at rest.
- Generate this key once on the VPS with a secure random source.
- Store it in `/opt/medveris/compose/.env` with restrictive permissions.
- Losing the key can make n8n credential encryption unrecoverable.

## Persistence
- n8n configuration and credentials are persisted in the n8n PostgreSQL volume
  `medveris_n8n_postgres_data`.
- Do not delete this volume during normal deployment or rollback.

## Security reminders
- Do not use the native PostgreSQL 18.6 cluster for n8n unless separately
  approved.
- Do not expose port 5678 publicly.
- Do not open firewall access to 5678 without explicit approval.
- Do not create n8n roles or databases in the native PostgreSQL cluster.
