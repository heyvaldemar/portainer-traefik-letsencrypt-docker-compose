# Portainer + Traefik + Let's Encrypt — Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository deploys **Portainer CE** — a web UI for managing the Docker host it runs on — behind **Traefik** with automatic **Let's Encrypt TLS**, including a routed endpoint for remote Edge agents.

📙 Full narrative installation guide on the blog: [heyvaldemar.com/install-portainer-using-docker-compose/](https://www.heyvaldemar.com/install-portainer-using-docker-compose/).

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose
cd portainer-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create portainer-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env

# 4. Deploy
docker compose -f portainer-traefik-letsencrypt-docker-compose.yml -p portainer up -d
```

**Open the UI immediately after deploy.** Portainer's first-run screen creates the admin account, and the installation locks itself after 5 minutes for security — if you miss the window, `docker restart portainer-portainer-1` re-opens it.

### What success looks like

```bash
docker compose -f portainer-traefik-letsencrypt-docker-compose.yml -p portainer ps
curl -fsk "https://${PORTAINER_FRONTEND_HOSTNAME}/api/system/status"   # {"Version":"2.45.0",...}
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet.
- **\"New Portainer installation\" timeout page.** More than 5 minutes passed before the first visit — restart the Portainer container and create the admin right away.
- **Networks not found.** Step 2 was skipped.

## Supply chain trust

Two images — [`traefik`](https://hub.docker.com/_/traefik) and [`portainer/portainer-ce`](https://hub.docker.com/r/portainer/portainer-ce) — pinned to `tag@sha256:<digest>` as interpolation defaults in the compose `x-images` block. `git pull` alone delivers the tested combination; an `*_IMAGE_TAG` variable in `.env` overrides deliberately.

The daily `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Create the admin account within 5 minutes of first start** — the installer locks itself after that.
- [ ] **Strong admin password** — Portainer has full control of the Docker socket, which is root on the host.
- [ ] **Regenerate the Traefik dashboard hash** — never ship the placeholder.
- [ ] **Treat this as an admin surface**: consider IP-allowlisting the hostname at your firewall; every Portainer session can start privileged containers.
- [ ] **Verify Let's Encrypt cert issuance** in the Traefik logs on first start.

## Unattended updates

Releases are the update channel: a tag is cut only after CI has built the pinned images, booted the full stack, and passed the smoke tests. `update.sh` moves a deployment to the newest tag and nothing else:

```bash
./update.sh --dry-run   # show what would be applied
./update.sh             # update within the current major and redeploy
```

Put it on a timer for hands-off minor/patch updates:

```bash
# crontab -e
17 5 * * *  /opt/portainer-traefik-letsencrypt-docker-compose/update.sh >> /var/log/portainer-update.log 2>&1
```

The script refuses to cross a MAJOR template version on its own — majors are breaking by definition and their release notes exist to be read. After reading them, `./update.sh --allow-major` performs the jump. It also refuses to touch a checkout with local modifications: your customization belongs in `.env`, which updates never overwrite.

This is deliberately a host-side script and not a container in the stack: an in-stack updater needs the Docker socket (root on the host) and turns "someone pushed to a repo" into "someone deployed to your machine" with no operator in the loop. A cron job under your own user updates only to tagged, CI-verified states and leaves the trust boundary where it was.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults — the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Backups

The `backups` container runs on a loop: an initial delay (`PORTAINER_BACKUP_INIT_SLEEP`, default 30m), then every `PORTAINER_BACKUP_INTERVAL` (default 24h) it takes a `tar.gz` of the rest of the data directory (live database files excluded), into the `portainer-backups` volume; files older than `PORTAINER_BACKUP_PRUNE_DAYS` (default 7) are pruned. Each artefact logs `... backup OK: <file> (<bytes> bytes)` or `FAILED` (kept as `<file>.failed`) — grep the log for `FAILED` from your monitoring.

**Verify backups are running:**

```bash
docker compose -p portainer logs backups | tail -5
docker compose -p portainer exec backups ls -la /srv/portainer/backups/
```

**Restore** a backup set with the interactive script (`chmod +x portainer-restore-data.sh` once): it stops portainer, unpacks the data archive over the data directory, and starts portainer again.

```bash
./portainer-restore-data.sh
```

**Off-host replication.** Backups live in a named volume on the same host — bind-mount `PORTAINER_BACKUPS_PATH` to a directory covered by your off-host backup solution (restic, rclone, Borg, S3 sync).

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC: actionlint, Trivy scans of both pinned images, the weekly freshness check, and a deploy-and-test job that boots the stack and requires the Portainer API to answer with its version JSON through Traefik.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the smoke test. The scenario that matters most is the restore roundtrip: the application is stopped, the baseline archive is unpacked over the data directory, and a file created after the baseline is gone. The tests stop the application briefly and write into its data directory — run them on a staging copy with short intervals in `.env` (`PORTAINER_BACKUP_INIT_SLEEP=15s`, `PORTAINER_BACKUP_INTERVAL=60s`), never on production.

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

## Security Notes

- Portainer mounts `/var/run/docker.sock` read-write by design — that is the product. Anyone with a Portainer admin session effectively has root on this host, so protect the login accordingly.
- `no-new-privileges:true` is set on the Portainer container.
- The Edge endpoint (port 8000) is routed but inert until you deploy Edge agents pointing at it.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
