# Deployment wrapper and sudoers design

This document describes the intended privileged execution model for
deploying, verifying, and rolling back the Medveris supporting services
on the Kamatera VPS.

This is a design document. Nothing here is installed on the VPS until it
has been reviewed.

## Goals

- The GitHub Actions runner stays a non-root user (`deploy`).
- Privileged actions are not open-ended `sudo`.
- The workflow can deploy/verify/rollback without embedding secrets or
  asking for a password in the job logs.
- One-time provisioning actions remain separate and authenticated, not
  granted through a blanket sudoers rule.

## Important constraint

The workflow cannot safely ship secrets or password prompts through job
logs. Any model that requires the workflow to type a `deploy` password
into `sudo` is therefore not acceptable here.

For that reason, the deploy path should use a narrow root-owned wrapper
with a targeted sudoers entry, while the initial provisioning steps are
done by an operator through an authenticated TTY session.

## Deployment wrapper

Proposed path: `/usr/local/bin/medveris-supporting-services-deploy`

Ownership: `root:root`
Permissions: `0755`

Purpose:
- Validate, deploy, verify, or rollback the Compose stack under
  `/opt/medveris/compose`.
- Only allow exactly these actions.
- Only operate on the fixed deployment directory.
- Never pass through secrets from arguments or environment.
- Never run arbitrary commands from workflow inputs.

Proposed wrapper behavior:

- If called with `validate`, run `docker compose config --quiet`
  against `/opt/medveris/compose/compose.yml` or the repo copy, as
  appropriate.
- If called with `deploy`, run the deployment script against
  `/opt/medveris/compose`.
- If called with `verify`, run the verification script against
  `/opt/medveris/compose`.
- If called with `status`, report compose status.
- If called with `rollback`, run the rollback script against
  `/opt/medveris/compose`.
- Any other argument is rejected.

The wrapper should not:
- Accept a deploy path from the caller.
- Accept arbitrary shell fragments.
- Read or write files outside the deployment directory.
- Start or stop the runner service.
- Modify UFW, SSH, or the native PostgreSQL configuration.
- Install packages or manipulate system services.

The wrapper may use `docker compose` and the scripts under version
control. It should not bemodifiable by the `deploy` user.

## Sudoers entry

Proposed entry for the `deploy` user:

- Allow `deploy` to run only the wrapper with no password.
- Use the exact full path.
- Use `NOEXEC` or equivalent restrictions if available, to reduce the
  chance of shell escapes through the wrapper.
- Do not grant general `sudo` to `deploy`.
- Do not add `deploy` to the `docker` group as part of this model.

Example shape, to be finalized during review:

```
deploy ALL=(root) NOEXEC: /usr/local/bin/medveris-supporting-services-deploy
```

This is intentionally narrow. If a command should ever need to run as
root and it is not that wrapper, it should be done by an operator
through authenticated TTY, not added to sudoers.

## What is not delegated to sudoers

These should remain manual, authenticated actions:

- Docker installation and enabling/starting the Docker service.
- Creating `/opt/medveris/compose` and setting its ownership.
- Creating and populating `/opt/medveris/compose/.env`.
- Editing UFW rules.
- Editing SSH configuration.
- Reinstalling or restarting the runner service.
- Rebooting the host.

## Secret handling

Secrets must not be passed through the workflow as arguments or printed
in logs. The intended model is:

- Secrets live only in `/opt/medveris/compose/.env`.
- The `.env` file is created by an operator through authenticated TTY.
- The file is mode `0600` and owned by `root` or by a carefully chosen
  service user, depending on the final access model.
- The wrapper reads compose configuration that references the `.env`
  file; it does not echo its contents.

## Review checklist before install

- The wrapper path, ownership, and permissions are fixed.
- The sudoers line is exactly the wrapper and nothing else.
- No `deploy` access to a general shell via sudo.
- No `deploy` in the `docker` group unless explicitly approved.
- The wrapper cannot be overwritten by `deploy`.
- The wrapper rejects unknown actions.
- Secrets are handled only through the protected `.env` file.

## Open decision

We still need to choose the Docker access model:

- Option A: add `deploy` to the `docker` group, with explicit risk
  acknowledgement.
- Option B: keep `deploy` out of the docker group and use the narrow
  wrapper plus sudoers for compose actions only.

This document assumes Option B is the intended default, because it avoids
broad Docker access for the runner user. If Option A is chosen instead,
the sudoers wrapper may still be useful for validation and rollback, but
the risk model changes and should be noted explicitly before install.
