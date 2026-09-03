# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.4.0] - 2026-09-02

### Added

- **`tests/e2e-backup-restore.sh`** — scenarios against the live stack,
  run by CI on every push: the required-variable guard fires, a backup
  set is produced, the archive is readable, a cycle that cannot
  write its archive is reported as `FAILED`, **restore genuinely
  replaces the data** (the application is stopped, the baseline archive is unpacked over the data directory, and a file created after the baseline is gone), and pruning removes only old files.

## [1.3.0] - 2026-09-02

### Added

- **A `backups` service** for Portainer's BoltDB database and settings (a copy taken while Portainer runs is consistent enough for BoltDB's single-writer model; for a guaranteed-consistent snapshot use Settings -> Backup in the UI or stop Portainer briefly): on a loop it takes a `tar.gz` of the rest of the data directory (live database files excluded), logs `OK` or `FAILED` per artefact (a failed archive is kept as `.failed`), and prunes only its own files. Schedule knobs (`PORTAINER_BACKUP_INIT_SLEEP`, `PORTAINER_BACKUP_INTERVAL`, `PORTAINER_BACKUP_PRUNE_DAYS`, path and names) have defaults listed in `.env.example`.
- **`portainer-restore-data.sh`** — interactive restore of a backup set: stops portainer, unpacks the data archive, restores each database copy, starts portainer.
- CI waits for the first backup cycle and proves the archives are readable.

## [1.2.0] - 2026-09-02

### Added

- **Resource limits on every service, as `.env`-overridable defaults.**
  Each service now carries memory and CPU limits plus reservations
  (`<SERVICE>_MEMORY_LIMIT`, `_CPU_LIMIT`, `_MEMORY_RESERVATION`,
  `_CPU_RESERVATION`, defaults listed in `.env.example`). Set any of
  them in `.env` and the override survives every `git pull`. The
  defaults are what CI boots the stack under, so they are known to be
  enough for a fresh install; raise a limit if a service is OOM-killed
  under your real load (`docker inspect` shows `OOMKilled=true`).

## [1.1.0] - 2026-09-02

### Added

- **`update.sh`** — unattended updates to the newest tagged release,
  and nothing else: a tag is cut only after CI has booted the pinned
  images and passed the smoke tests, so "update to the latest tag" means
  "update to a combination a machine has already run". It refuses to
  cross a major version on its own (`--allow-major` after reading the
  notes), refuses a checkout with local modifications, and supports
  `--dry-run`. Put it on a cron timer for hands-off minor/patch updates.

## [1.0.0] - 2026-08-31

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Changed

- **Portainer CE and Traefik pinned by `tag@sha256:digest`** in the compose
  `x-images` block (Portainer CE 2.45.0, Traefik 3.7 — 3.2's Docker client
  cannot talk to Docker Engine 29). `git pull` delivers the tested
  combination; `.env` carries only hostnames and the dashboard credentials.
- Required variables now fail fast with `:?` guards instead of producing a
  half-configured stack.

### Fixed

- Misspelled `portaier-edge` router/service names (cosmetic, but they leaked
  into the Traefik dashboard).

### Added

- **Deployment Verification workflow**: actionlint; Trivy scans of both
  pinned images; weekly `check-pin-freshness` (digest drift + Portainer and
  Traefik release lag); and a deploy-and-test job that boots the stack and
  requires the Portainer API to answer with its version through Traefik.
- `.env.example` with generation commands; `.env` gitignored.

[Unreleased]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/portainer-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
