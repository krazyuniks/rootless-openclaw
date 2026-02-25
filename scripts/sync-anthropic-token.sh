#!/bin/bash
#
# Sync Anthropic OAuth token from Claude CLI credentials into OpenClaw agent auth profiles.
# Run as root via cron, e.g.: 0 */6 * * * /home/openclaw/rootless-openclaw/scripts/sync-anthropic-token.sh
#
set -euo pipefail

CLAUDE_CREDS="/home/ryan/.claude/.credentials.json"
AGENTS_DIR="/home/openclaw/.openclaw/agents"

TOKEN=$(python3 -c "
import json
with open('$CLAUDE_CREDS') as f:
    print(json.load(f)['claudeAiOauth']['accessToken'])
")

if [ -z "$TOKEN" ]; then
    echo "ERROR: No access token found in $CLAUDE_CREDS" >&2
    exit 1
fi

for auth_file in "$AGENTS_DIR"/*/agent/auth-profiles.json; do
    [ -f "$auth_file" ] || continue
    python3 -c "
import json, sys
with open('$auth_file') as f:
    auth = json.load(f)
auth['profiles']['anthropic:default'] = {
    'type': 'api_key',
    'provider': 'anthropic',
    'key': '$TOKEN'
}
auth.setdefault('lastGood', {})['anthropic'] = 'anthropic:default'
with open('$auth_file', 'w') as f:
    json.dump(auth, f, indent=2)
    f.write('\n')
"
done

echo "$(date -Iseconds) Synced Anthropic token to all agents"
