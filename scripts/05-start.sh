#!/bin/bash
#
# Start OpenClaw gateway
#

set -e

USER="${OPENCLAW_USER:-openclaw}"
IMAGE_NAME="openclaw:local"
CONTAINER_NAME="openclaw-gateway"
PORT=18789

# Load API keys from .openclaw/.env (as per OpenClaw docs)
ENV_FILE="/home/$USER/.openclaw/.env"

# Use sudo only if not running as the target user
if [ "$(whoami)" = "$USER" ]; then
    SUDO=""
    DOCKER="docker"
else
    SUDO="sudo -u $USER"
    DOCKER="sudo -u $USER docker"
fi

echo "==> Starting OpenClaw gateway"

# Stop existing container if running
if $DOCKER ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo "==> Stopping existing container..."
    $DOCKER rm -f "$CONTAINER_NAME"
fi

# Remove stale session lock files from previous container
LOCK_FILES=$(find "/home/$USER/.openclaw" -name '*.lock' -type f 2>/dev/null || true)
if [ -n "$LOCK_FILES" ]; then
    echo "==> Removing stale lock files..."
    echo "$LOCK_FILES" | while read -r f; do rm -f "$f"; done
fi

# Build environment variable flags
ENV_FLAGS=""
[ -f "$ENV_FILE" ] && ENV_FLAGS="--env-file $ENV_FILE"

# Start gateway
echo "==> Starting gateway on port $PORT..."
$DOCKER run -d --rm \
    -p "127.0.0.1:$PORT:$PORT" \
    -v "/home/$USER/.openclaw:/home/node/.openclaw" \
    --log-opt max-size=50m --log-opt max-file=3 \
    $ENV_FLAGS \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" \
    node dist/index.js gateway --bind lan

echo ""
echo "✓ Gateway started"
echo ""

# Extract and display the auth token (from .env or openclaw.json)
TOKEN=""
if [ -f "$ENV_FILE" ]; then
    TOKEN=$(grep -m1 '^OPENCLAW_GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
fi

if [ -n "$TOKEN" ]; then
    echo "==> Your auth token:"
    echo "$TOKEN"
    echo ""
    echo "==> Access dashboard at:"
    echo "http://127.0.0.1:$PORT/?token=$TOKEN"
else
    echo "==> Auth token not found in $ENV_FILE"
    echo "    Set OPENCLAW_GATEWAY_TOKEN in $ENV_FILE"
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
