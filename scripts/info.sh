#!/bin/bash
#
# Display OpenClaw service status, token, and pairing information
#

set -e

USER="${OPENCLAW_USER:-openclaw}"
CONTAINER_NAME="openclaw-gateway"
PORT=18789

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No colour

# Use sudo only if not running as the target user
if [ "$(whoami)" = "$USER" ]; then
    DOCKER="docker"
else
    DOCKER="sudo -u $USER docker"
fi

echo ""
echo -e "${BLUE}==> OpenClaw Service Status${NC}"
echo ""

# Check container status
if $DOCKER ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    CONTAINER_STATUS=$($DOCKER ps --format '{{.Status}}' -f name="$CONTAINER_NAME")
    echo -e "Container:  ${GREEN}Running${NC} ($CONTAINER_STATUS)"
else
    echo -e "Container:  ${RED}Not running${NC}"
    echo ""
    echo "Start with: /home/$USER/rootless-openclaw/scripts/05-start.sh"
    exit 1
fi

# Check port
if netstat -tlnp 2>/dev/null | grep -q ":$PORT " || ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
    echo -e "Port $PORT: ${GREEN}Listening${NC}"
else
    echo -e "Port $PORT: ${YELLOW}Not detected${NC} (may still be accessible)"
fi

echo ""
echo -e "${BLUE}==> Auth Token${NC}"
echo ""

# Get token from .env
ENV_FILE="/home/$USER/.openclaw/.env"
TOKEN=""
if [ -f "$ENV_FILE" ]; then
    TOKEN=$(grep -m1 '^OPENCLAW_GATEWAY_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
fi

if [ -n "$TOKEN" ]; then
    echo "$TOKEN"
else
    echo -e "${YELLOW}Could not retrieve token${NC}"
    echo ""
    echo "Set OPENCLAW_GATEWAY_TOKEN in $ENV_FILE"
fi

echo ""
echo -e "${BLUE}==> Dashboard URL${NC}"
echo ""

if [ -n "$TOKEN" ]; then
    echo "http://127.0.0.1:$PORT/?token=$TOKEN"
else
    echo "http://127.0.0.1:$PORT/?token=<your-token>"
fi

echo ""
echo -e "${BLUE}==> Device Pairing${NC}"
echo ""

# List paired devices
echo "Paired/pending devices:"
$DOCKER exec "$CONTAINER_NAME" node dist/index.js devices list 2>/dev/null || echo "  (Could not list devices)"

echo ""
echo -e "${BLUE}==> Pairing Commands${NC}"
echo ""
echo "List pending requests:"
echo "  $DOCKER exec $CONTAINER_NAME node dist/index.js devices list"
echo ""
echo "Approve a browser pairing:"
echo "  $DOCKER exec $CONTAINER_NAME node dist/index.js devices approve <REQUEST_ID>"
echo ""
echo "Approve Telegram pairing:"
echo "  $DOCKER exec $CONTAINER_NAME node dist/index.js pairing approve telegram <CODE>"

echo ""
echo -e "${BLUE}==> Quick Reference${NC}"
echo ""
echo "Logs:     $DOCKER logs -f $CONTAINER_NAME"
echo "Restart:  /home/$USER/rootless-openclaw/scripts/05-start.sh"
echo "SSH tunnel: ssh -L $PORT:127.0.0.1:$PORT $USER@<server>"
echo ""
