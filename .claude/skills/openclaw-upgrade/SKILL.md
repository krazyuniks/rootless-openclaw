---
name: openclaw-upgrade
description: Upgrade OpenClaw to a specific version or latest. Use when the user wants to update, upgrade, or reinstall OpenClaw. Handles git checkout, Docker image rebuild, and gateway restart.
---

# OpenClaw Upgrade Skill

Upgrade the OpenClaw installation to a specified version tag.

## Prerequisites

- Must run as the `openclaw` user (owns the repo and rootless Docker)
- If running as another user: `sudo -u openclaw -E claude` (preserves auth credentials)

**CRITICAL**:
- All `docker` commands MUST run as the `openclaw` user — rootless Docker daemons have separate image stores per user
- All `git` commands SHOULD run as `openclaw` to preserve file ownership
- Always use `--no-cache` on `docker build` during upgrades — BuildKit's cache does not reliably detect source changes across git checkouts

## Arguments

- `$ARGUMENTS` — version tag (e.g. `2026.2.9` or `v2026.2.9`). If empty, upgrade to latest tag.

## Paths

| Path | Purpose |
|------|---------|
| `/home/openclaw/openclaw` | OpenClaw git repo |
| `/home/openclaw/.openclaw` | OpenClaw config/workspace |
| `/home/openclaw/rootless-openclaw` | This deployment repo |
| `/home/openclaw/rootless-openclaw/scripts/05-start.sh` | Gateway start script |
| `/home/openclaw/rootless-openclaw/.env` | API keys (BRAVE_API_KEY, etc.) |

## Workflow

### 1. Determine target version

```bash
# Fetch latest tags
$SUDO git -C /home/openclaw/openclaw fetch --tags

# If no version specified, find the latest tag
$SUDO git -C /home/openclaw/openclaw tag --sort=-v:refname | head -5

# Show current version
$SUDO git -C /home/openclaw/openclaw describe --tags
```

Normalise the version: if user provides `2026.2.9`, prefix with `v` → `v2026.2.9`.

Verify the tag exists before proceeding:
```bash
$SUDO git -C /home/openclaw/openclaw tag -l "v2026.2.9"
```

### 2. Detect current user and set up commands

If not running as `openclaw`, prefix ALL commands with `sudo -u openclaw`:

```bash
if [ "$(whoami)" = "openclaw" ]; then
    SUDO=""
    DOCKER="docker"
else
    SUDO="sudo -u openclaw"
    DOCKER="sudo -u openclaw docker"
fi
```

Use `$SUDO` for git commands and `$DOCKER` for docker commands. Running git as the wrong user changes file ownership, which breaks Docker build cache and leaves the repo in a bad state.

### 3. Check for running container

```bash
$DOCKER ps --filter name=openclaw-gateway --format '{{.Names}} {{.Image}} {{.Status}}'
```

If running, inform the user it will be stopped during the upgrade.

### 4. Checkout target version

```bash
$SUDO git -C /home/openclaw/openclaw checkout v2026.2.9
```

### 5. Rebuild Docker image

```bash
$DOCKER build --no-cache -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
```

Always use `--no-cache` — BuildKit's cache is unreliable across git checkouts. This takes several minutes. Run with a longer timeout.

### 6. Restart gateway

```bash
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```

### 7. Verify

```bash
$DOCKER ps --filter name=openclaw-gateway --format '{{.Names}} {{.Image}} {{.Status}}'
$DOCKER exec openclaw-gateway node -e "console.log(require('./package.json').version)"
```

Report the upgrade result: previous version → new version.

## Rollback

If the upgrade fails, checkout the previous tag and rebuild:
```bash
$SUDO git -C /home/openclaw/openclaw checkout <previous-tag>
$DOCKER build --no-cache -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```

## Guidelines

- Always confirm the target version exists before checking out
- Show the user what version they're upgrading from and to
- The Docker build can take several minutes — use a longer timeout
- Do NOT run `docker-setup.sh` for upgrades (that runs onboarding). Only use it for fresh installs.
- The start script in `05-start.sh` handles stopping any existing container automatically
