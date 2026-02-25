# Rootless OpenClaw Deployment

Automated deployment of [OpenClaw](https://github.com/openclaw/openclaw) using rootless Docker.

## Architecture

- **Dedicated user**: `openclaw` — owns all OpenClaw files and runs rootless Docker
- **OpenClaw repo**: `/home/openclaw/openclaw` (cloned from GitHub, checked out to a version tag)
- **Config/data**: `/home/openclaw/.openclaw/` (mounted into container at `/home/node/.openclaw`)
- **Deployment scripts**: `/home/openclaw/rootless-openclaw/scripts/`
- **Docker image**: `openclaw:local` (built from OpenClaw's Dockerfile)
- **Container name**: `openclaw-gateway`
- **Gateway port**: 18789

## Running Claude as the openclaw user

Since the openclaw user owns the repo and Docker daemon:

```bash
sudo -u openclaw -E claude
```

The `-E` flag preserves your environment (including Claude auth credentials from `~/.claude/.credentials.json`).

## Key scripts

| Script | Purpose |
|--------|---------|
| `scripts/01-user-setup.sh` | Create openclaw user with subuid/subgid |
| `scripts/03-docker-rootless.sh` | Install rootless Docker for openclaw user |
| `scripts/04-openclaw.sh` | Clone repo, create dirs, run onboarding |
| `scripts/05-start.sh` | Stop/start gateway container |
| `scripts/info.sh` | Show service status, token, and connection info |
| `scripts/sync-oauth-tokens.sh` | Sync Anthropic + Gemini OAuth tokens into agent auth profiles |

## UID mapping

| Container UID | Host UID | Identity |
|---|---|---|
| 0 (root) | 1001 | `openclaw` host user |
| 1000 (node) | 166535 | container process owner |

All files in `/home/openclaw/.openclaw/` must be owned by `166535:166535`. ACLs grant `openclaw` and `ryan` access.

## OAuth Token Sync

OpenClaw uses OAuth tokens from host CLI tools, stored as `api_key` type in agent auth profiles:

- **Anthropic**: from Claude CLI (`/home/ryan/.claude/.credentials.json`)
- **Google Gemini CLI**: from Gemini CLI (`/home/ryan/.gemini/oauth_creds.json`)
- **ZAI**: API key only (no OAuth), stored directly in auth profiles

Tokens are synced into `/home/openclaw/.openclaw/agents/*/agent/auth-profiles.json`.

- **Sync script**: `scripts/sync-oauth-tokens.sh` (run as root via cron)
- **Cron** (root): `0 */6 * * * /home/openclaw/rootless-openclaw/scripts/sync-oauth-tokens.sh >> /tmp/openclaw-token-sync.log 2>&1`
- **Token lifespan**: ~30 days. Refreshed each time the respective CLI runs on the host.
- **Format**: stored as `"type": "api_key"` with the OAuth access token as `"key"` — OpenClaw doesn't support native OAuth format.

## Upgrading

Use the `/openclaw-upgrade` skill or see `.claude/skills/openclaw-upgrade/SKILL.md`.

Quick manual upgrade:
```bash
git -C /home/openclaw/openclaw fetch --tags
git -C /home/openclaw/openclaw checkout v<VERSION>
docker build -t openclaw:local -f /home/openclaw/openclaw/Dockerfile /home/openclaw/openclaw
/home/openclaw/rootless-openclaw/scripts/05-start.sh
```
