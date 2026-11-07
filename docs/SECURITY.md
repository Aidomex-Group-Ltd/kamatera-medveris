# Security Documentation

## SSH Access

> **WARNING — SSH NOT HARDENED (independently verified 2026-11-07):**
> - `PermitRootLogin yes` — root CAN log in via SSH (sshd -T confirmed)
> - `PasswordAuthentication yes` — password auth IS ENABLED (sshd -T confirmed)
> - SSH listens on `0.0.0.0:22` and `[::]:22` — all interfaces
> - UFW is ACTIVE but only allows SSH — no additional restriction on SSH source IPs
> - No fail2ban — no brute-force protection
> **These settings MUST be hardened before the server is considered secure.**
> **However, UFW is active and protecting all non-SSH ports.**

- **Authentication:** Target is key-only (password authentication to be disabled)
- **Working Key:** `~/.ssh/medveris_kamatera` (private) / `medveris-kamatera-deploy` (public)
  - Fingerprint: verify before use
  - **Do not hardcode SSH public keys in this file.** Reference the key file path instead.
- **Verification:** Key-based SSH access verified working 2026-11-07
- **UFW status:** ACTIVE — default deny incoming, allow outgoing; SSH allowed on IPv4+IPv6
- **Second Session:** Required before changing SSH config (PermitRootLogin, PasswordAuthentication)
- **Hardening required:** Disable `PermitRootLogin`, disable `PasswordAuthentication`.
  UFW SSH rule is already in place. Consider restricting SSH to trusted IPs via UFW.
  All changes require sudo and a second SSH session.

## Firewall (UFW)

> **VERIFIED ACTIVE (independently verified 2026-11-07):**
> ```
> Status: active
> Logging: on (low)
> Default: deny (incoming), allow (outgoing), disabled (routed)
> 
> To                         Action      From
> --                         ------      ----
> 22/tcp (OpenSSH)           ALLOW IN    Anywhere
> 22/tcp (OpenSSH (v6))      ALLOW IN    Anywhere (v6)
> ```
> UFW was enabled after the Phase 0 baseline. Default incoming policy is deny.
> SSH (OpenSSH profile, TCP 22) is allowed on IPv4 and IPv6.

- **SSH:** Allowed on IPv4+IPv6 (OpenSSH profile). Consider restricting to trusted IPs.
- **HTTP/HTTPS:** Not yet allowed — no web services deployed. Add rules when deploying.
- **PostgreSQL (5432):** Blocked by UFW default deny + bound to localhost + pg_hba.conf restriction
- **Ollama API:** Blocked by UFW default deny (not installed)
- **R2 Access:** Via Cloudflare Workers secrets only

## PostgreSQL Security

- **Superuser Usage:** Never use `postgres` superuser for applications
- **Authentication:** SCRAM-SHA-256 only
- **Connection Limits:** Appropriate limits per service
- **Network:** Bound to private interfaces; Hyperdrive provides pooled access
- **Roles:** Separate `medveris_runtime`, `medveris_jobs`, `n8n` roles
- **RLS:** Row-level security policies enforced per tenant

## Ollama Security

- **API Binding:** 127.0.0.1 or internal network only
- **Public Exposure:** Never expose Ollama API publicly
- **Model Access:** Small quantized models only initially
- **Memory Limits:** Resource caps enforced; no GPU assumed

## n8n Security

- **Authentication:** Required for all admin interfaces
- **Webhook Security:** Signed webhooks only; secret validation
- **Database Isolation:** Dedicated PostgreSQL database and account
- **Encryption Key:** Persistent, vault-managed
- **Execution History:** Retention policy with secure deletion

## Infrastructure Secrets

- **Never Commit:** SSH private keys, API keys, passwords, database URLs
- **Terraform State:** Remote, securely managed state (no secrets in state)
- **Ansible Vault:** Use for sensitive role variables
- **Cloudflare Secrets:** Use `wrangler secret put` for Worker secrets
- **Environment Variables:** Placeholder values blocked at startup

## Firewall Rules Summary

| Service | Port | Access |
|---|---|---|
| SSH | 22 | Trusted IPs only |
| HTTP | 80 | Anywhere (redirect to HTTPS) |
| HTTPS | 443 | Anywhere (Cloudflare TLS) |
| PostgreSQL | 5432 | Blocked by UFW default deny + localhost binding + pg_hba.conf |
| Ollama API | 11434 | Blocked by UFW default deny (not installed) |
| Nginx | 80/443 | Not yet allowed (no services deployed) |
