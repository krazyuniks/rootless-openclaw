#!/bin/bash
#
# Rootless OpenClaw Deployment Installer
#
# Usage:
#   git clone https://github.com/krazyuniks/rootless-docker-openclaw.git /tmp/rootless-docker-openclaw
#   cd /tmp/rootless-docker-openclaw
#   sudo ./install.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configurable username (default: openclaw)
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
export OPENCLAW_USER
DEPLOY_DIR="/home/$OPENCLAW_USER/rootless-docker-openclaw"

echo "==================================="
echo " Rootless OpenClaw Deployment"
echo "==================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh"
    exit 1
fi

# Run each setup step
"$SCRIPT_DIR/scripts/01-user-setup.sh"
echo ""

"$SCRIPT_DIR/scripts/02-firewall.sh"
echo ""

"$SCRIPT_DIR/scripts/03-docker-rootless.sh"
echo ""

"$SCRIPT_DIR/scripts/04-openclaw.sh"
echo ""

# Copy deployment repo to user home
echo "==> Copying deployment repo to $DEPLOY_DIR..."
sudo -u "$OPENCLAW_USER" cp -r "$SCRIPT_DIR" "$DEPLOY_DIR"
echo "✓ Deployment repo installed to $DEPLOY_DIR"
echo ""

"$SCRIPT_DIR/scripts/05-start.sh"
echo ""

echo "==================================="
echo " Installation Complete!"
echo "==================================="
echo ""
echo "Deployment repo is now at: $DEPLOY_DIR"
echo ""
echo "To manage OpenClaw:"
echo "  cd $DEPLOY_DIR"
echo "  sudo ./scripts/05-start.sh      # Start gateway"
echo "  sudo -u $OPENCLAW_USER docker logs -f openclaw-gateway  # View logs"
echo ""
