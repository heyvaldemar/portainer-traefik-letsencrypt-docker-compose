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

The weekly `check-pin-freshness` CI job re-resolves each pin against its registry and compares the pinned versions against the latest upstream releases. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

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

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every Monday at 06:00 UTC: actionlint, Trivy scans of both pinned images, the weekly freshness check, and a deploy-and-test job that boots the stack and requires the Portainer API to answer with its version JSON through Traefik.

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
