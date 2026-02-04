#!/bin/bash
#
# Start OpenClaw gateway
#

set -e

USER="${OPENCLAW_USER:-openclaw}"
IMAGE_NAME="openclaw:local"
CONTAINER_NAME="openclaw-gateway"
PORT=18789

# Load API keys from env file if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Optional API keys (set these in environment, env file, or edit here)
BRAVE_API_KEY="${BRAVE_API_KEY:-}"

# Use sudo only if not running as the target user
if [ "$(whoami)" = "$USER" ]; then
    SUDO=""
    DOCKER="docker"
    SUDO_CAT="cat"
else
    SUDO="sudo -u $USER"
    DOCKER="sudo -u $USER docker"
    SUDO_CAT="sudo cat"
fi

echo "==> Starting OpenClaw gateway"

# Stop existing container if running
if $DOCKER ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo "==> Stopping existing container..."
    $DOCKER rm -f "$CONTAINER_NAME"
fi

# Build environment variable flags
ENV_FLAGS=""
[ -n "$BRAVE_API_KEY" ] && ENV_FLAGS="$ENV_FLAGS -e BRAVE_API_KEY=$BRAVE_API_KEY"

# Start gateway
echo "==> Starting gateway on port $PORT..."
$DOCKER run -d --rm \
    -p "$PORT:$PORT" \
    -v "/home/$USER/.openclaw:/home/node/.openclaw" \
    $ENV_FLAGS \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" \
    node dist/index.js gateway --bind lan

echo ""
echo "✓ Gateway started"
echo ""

# Extract and display the auth token
TOKEN=$($DOCKER run --rm -v "/home/$USER/.openclaw:/home/node/.openclaw" "$IMAGE_NAME" \
    node -e "const c = require('/home/node/.openclaw/openclaw.json'); console.log(c.gateway.auth.token)" 2>/dev/null)

if [ -n "$TOKEN" ]; then
    echo "==> Your auth token:"
    echo "$TOKEN"
    echo ""
    echo "==> Access dashboard at:"
    echo "http://127.0.0.1:$PORT/?token=$TOKEN"
else
    echo "==> Get your auth token:"
    echo "$SUDO_CAT /home/$USER/.openclaw/openclaw.json | jq -r '.gateway.auth.token'"
    echo ""
    echo "==> Access dashboard at:"
    echo "http://127.0.0.1:$PORT/?token=<your-token>"
fi
echo ""
echo "==> View logs:"
echo "$DOCKER logs -f $CONTAINER_NAME"
echo ""
echo "==> Or create SSH tunnel from local machine:"
echo "ssh -L $PORT:127.0.0.1:$PORT $USER@<server>"
echo ""
echo "==> First-time browser pairing:"
echo "When you first open the dashboard, you'll see 'pairing required'."
echo "Run these commands to approve your browser:"
echo ""
echo "  # List pending pairing requests"
echo "  $DOCKER exec $CONTAINER_NAME node dist/index.js devices list"
echo ""
echo "  # Approve a request (use the Request ID from the list)"
echo "  $DOCKER exec $CONTAINER_NAME node dist/index.js devices approve <REQUEST_ID>"
