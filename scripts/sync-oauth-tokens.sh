#!/bin/bash
#
# Sync OAuth tokens from host CLI credentials into OpenClaw agent auth profiles.
# - Anthropic: from Claude CLI (~ryan/.claude/.credentials.json) — stored as api_key
# - Google Gemini CLI: from Gemini CLI (~ryan/.gemini/oauth_creds.json) — stored as oauth
# Run as root via cron, e.g.: 0 */6 * * * /home/openclaw/rootless-openclaw/scripts/sync-oauth-tokens.sh
#
set -euo pipefail

CLAUDE_CREDS="/home/ryan/.claude/.credentials.json"
GEMINI_CREDS="/home/ryan/.gemini/oauth_creds.json"
AGENTS_DIR="/home/openclaw/.openclaw/agents"

for auth_file in "$AGENTS_DIR"/*/agent/auth-profiles.json; do
    [ -f "$auth_file" ] || continue
    python3 -c "
import json

with open('$CLAUDE_CREDS') as f:
    claude = json.load(f)
with open('$GEMINI_CREDS') as f:
    gemini = json.load(f)
with open('$auth_file') as f:
    auth = json.load(f)

# Anthropic: OAuth access token as api_key (OpenClaw doesn't support native OAuth for Anthropic)
auth['profiles']['anthropic:default'] = {
    'type': 'api_key',
    'provider': 'anthropic',
    'key': claude['claudeAiOauth']['accessToken']
}

# Gemini CLI: native OAuth format with refresh token
auth['profiles']['google-gemini-cli:default'] = {
    'type': 'oauth',
    'provider': 'google-gemini-cli',
    'access': gemini['access_token'],
    'refresh': gemini['refresh_token'],
    'expires': gemini['expiry_date'],
    'projectId': 'noted-reef-487516-t9'
}

auth.setdefault('lastGood', {})['anthropic'] = 'anthropic:default'
auth.setdefault('lastGood', {})['google-gemini-cli'] = 'google-gemini-cli:default'

with open('$auth_file', 'w') as f:
    json.dump(auth, f, indent=2)
    f.write('\n')
"
done

echo "$(date -Iseconds) Synced Anthropic + Gemini tokens to all agents"
