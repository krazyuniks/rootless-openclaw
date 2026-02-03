# Rootless OpenClaw Deployment

Automated deployment of OpenClaw with rootless Docker, nftables firewall, and proper UID/GID mapping.

**Designed for cloud servers, dedicated servers, and VPS instances. Also suitable for local installations.**

## Overview

This deployment automates the complete setup of OpenClaw as a non-root service using rootless Docker.

### Why This Matters

OpenClaw is an AI assistant that executes code and commands on your server. Running such a system as **root** is extremely risky—a compromised container would have complete control over your host. This deployment provides a secure, production-ready setup that:

- Isolates OpenClaw from the host system
- Minimizes attack surface through proper firewall configuration
- Uses least-privilege principles throughout
- Automates security best practices

### Security Risks Mitigated

| Risk | Without This Deployment | How This Repo Helps |
|------|------------------------|---------------------|
| **Root privilege escalation** | OpenClaw runs as root = full system access | Runs as unprivileged user with UID namespace isolation |
| **Firewall misconfiguration** | Manual setup often breaks Docker networking | Pre-configured nftables with Docker-aware rules |
| **Container escape impact** | Root container = host takeover | Non-root container limits damage scope |
| **Unnecessary exposed ports** | Services exposed to internet | Deny-all firewall with only essential ports open |
| **Docker daemon breaks on firewall reload** | Manual `flush ruleset` wipes NAT rules | Uses table-specific flush + systemd override |

### Security Features

| Feature | Security Benefit |
|---------|-----------------|
| **[Rootless Docker](https://docs.docker.com/engine/security/rootless/)** | OpenClaw has no root privileges; container escape doesn't grant root access |
| **UID namespace remapping** | Container UIDs map to different host UIDs, adding isolation layer |
| **nftables (deny-all)** | Only SSH (rate-limited), HTTP/HTTPS, and gateway port allowed |
| **Docker-aware firewall** | Forward chain explicitly allows bridge traffic only |
| **No exposed dashboard** | Gateway binds to localhost; requires SSH tunnel for access |
| **Docker survives firewall reload** | Systemd override prevents service disruption |

### What This Deployment Provides

- **[Rootless Docker](https://docs.docker.com/engine/security/rootless/)**: OpenClaw runs without root privileges
- **nftables firewall**: Pre-configured with Docker-aware rules
- **UID mapping**: Automatic configuration for container file access
- **Systemd integration**: Docker survives firewall reloads
- **SSH-only dashboard access**: Gateway requires tunnel for access

### Deployment Targets

| Environment | Recommended | Notes |
|-------------|-------------|-------|
| Cloud servers (AWS, GCP, Azure, DigitalOcean, etc.) | ✅ Yes | Ideal for production |
| Dedicated servers (Hetzner, OVH, etc.) | ✅ Yes | Full isolation |
| VPS instances | ✅ Yes | Resource-efficient |
| Local/VM (Linux) | ✅ Yes | Great for development |
| WSL2 | ⚠️ Possible | May need additional config |
| macOS | ❌ Not supported | nftables not available |

## Quick Start

```bash
# Clone and run installer
git clone https://github.com/krazyuniks/rootless-docker-openclaw.git /tmp/rootless-docker-openclaw
cd /tmp/rootless-docker-openclaw
sudo ./install.sh
```

The installer will:
1. Create the `openclaw` user
2. Configure nftables firewall (with Docker-forward rules)
3. Install rootless Docker
4. Clone OpenClaw source and run setup
5. Start the gateway

## Full Directory Structure

After installation, the complete structure is:

```
/home/openclaw/
├── openclaw/                          # Cloned from upstream during install
│   ├── docker-compose.yml             # Docker compose config
│   ├── docker-setup.sh                # Official setup script
│   ├── Dockerfile                     # Container build
│   ├── dist/                          # Built application
│   ├── apps/                          # OpenClaw apps
│   ├── agents/                        # AI agents
│   └── ...
│
├── rootless-docker-openclaw/           # This deployment repo
│   ├── install.sh                     # Main installer (chains all scripts)
│   ├── README.md                      # This file
│   ├── .gitignore
│   └── configs/
│       ├── nftables.conf              # Firewall rules (Docker-aware)
│       ├── docker-daemon.json         # Docker DNS config
│       └── systemd-docker-override.conf  # Docker restarts after nftables
│   └── scripts/
│       ├── 01-user-setup.sh           # Create openclaw user
│       ├── 02-firewall.sh             # Install nftables
│       ├── 03-docker-rootless.sh      # Install rootless Docker
│       ├── 04-openclaw.sh             # Clone & setup OpenClaw
│       └── 05-start.sh                # Start gateway
│
├── .openclaw/                          # Runtime config (created by OpenClaw)
│   ├── openclaw.json                  # Gateway configuration
│   ├── workspace/                     # Agent workspace
│   ├── agents/                        # AI agent configs
│   ├── credentials/                   # API keys
│   ├── canvas/                        # Agent canvas
│   ├── cron/                          # Scheduled tasks
│   ├── telegram/                      # Telegram bot config
│   └── devices/                       # Paired devices
│
├── .config/
│   └── docker/
│       └── daemon.json                # Docker daemon config (DNS)
│
└── bin/                                # Rootless Docker binaries
    ├── docker
    ├── dockerd
    ├── containerd
    ├── runc
    └── ...
```

## What This Provides

| Feature | Description |
|---------|-------------|
| **[Rootless Docker](https://docs.docker.com/engine/security/rootless/)** | OpenClaw runs as non-root user with UID namespace remapping |
| **nftables firewall** | Properly configured to work with Docker (avoids `flush ruleset`) |
| **Systemd integration** | Docker restarts after nftables reloads |
| **UID mapping** | Files owned correctly for container access |
| **Automated install** | Single script handles entire setup |

## Accessing the Dashboard

### Direct SSH (simplest)

```bash
# Create SSH tunnel from your local machine
ssh -L 18789:127.0.0.1:18789 openclaw@<server>

# Open in browser
http://127.0.0.1:18789/?token=<your-token>
```

### Via SSH Jump Host (for servers behind bastion)

If your server is only accessible through a jump host:

```bash
# Add to ~/.ssh/config on your local machine
Host bastion
    HostName bastion.example.com
    User your-user

Host openclaw-server
    HostName 192.168.1.100  # Private IP of OpenClaw server
    User openclaw
    ProxyJump bastion
    LocalForward 18789 127.0.0.1:18789

# Connect with single command
ssh openclaw-server

# Dashboard available at
http://127.0.0.1:18789/?token=<your-token>
```

### One-liner tunnel (quick access)

```bash
ssh -L 18789:127.0.0.1:18789 -l openclaw <server-hostname>
```

## Device Pairing

When you first access the dashboard, you'll see a "pairing required" error. This is a security feature - each browser/device must be approved before it can connect.

### Approve a Browser

```bash
# List pending pairing requests
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices list

# You'll see output like:
# Pending (1)
# ┌──────────────────────────────────────┬─────────────┬──────────┬────────────┐
# │ Request                              │ Device      │ Role     │ IP         │
# ├──────────────────────────────────────┼─────────────┼──────────┼────────────┤
# │ 6021dc52-04d9-42e6-826e-f9b620a19a3a │ 15c051a...  │ operator │ 172.18.0.1 │
# └──────────────────────────────────────┴─────────────┴──────────┴────────────┘

# Approve using the Request ID (first column)
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices approve 6021dc52-04d9-42e6-826e-f9b620a19a3a
```

After approval, refresh your browser - you should now be connected.

### List Paired Devices

```bash
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices list
```

## Quick Reference

```bash
# Get your auth token
sudo -u openclaw cat /home/openclaw/.openclaw/openclaw.json | jq -r '.gateway.auth.token'

# Start gateway
sudo -u openclaw docker run -d --rm -p 18789:18789 -v ~/.openclaw:/home/node/.openclaw --name openclaw-gateway openclaw:local node dist/index.js gateway --bind lan

# Stop gateway
sudo -u openclaw docker rm -f openclaw-gateway

# CLI commands (while gateway running)
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices list
sudo -u openclaw docker exec openclaw-gateway node dist/index.js devices approve <REQUEST_ID>
sudo -u openclaw docker exec openclaw-gateway node dist/index.js pairing approve telegram <CODE>
```

## Common Operations

### View Logs

```bash
sudo -u openclaw docker logs -f openclaw-gateway
```

### Restart Gateway

```bash
cd /home/openclaw/rootless-docker-openclaw
sudo ./scripts/05-start.sh
```

### Update OpenClaw

```bash
cd /home/openclaw/openclaw
sudo -u openclaw git pull
./docker-setup.sh
sudo ../rootless-docker-openclaw/scripts/05-start.sh
```

## Firewall (nftables + Docker)

The server uses nftables alongside Docker's iptables-nft rules.

| Component | Table | Purpose |
|-----------|-------|---------|
| Base firewall | `inet filter` | SSH, HTTP/HTTPS, input filtering |
| Docker | `ip filter`, `ip nat` | Container networking, MASQUERADE |

### Critical: Docker Forwarding Rules

The `inet filter forward` chain must allow Docker traffic:

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # Allow Docker container traffic
    iifname "docker*" accept
    iifname "br-*" accept
    oifname "docker*" accept
    oifname "br-*" accept

    # Allow established/related for return traffic
    ct state established,related accept
}
```

### Critical: Avoid `flush ruleset`

Using `flush ruleset` in nftables.conf wipes Docker's NAT rules, breaking container networking. Use table-specific flush instead:

```nft
# Only flush our table, not Docker's
flush table inet filter
```

### Fixing Broken Docker Networking

If containers lose internet connectivity after nftables changes:

```bash
# Test container connectivity
sudo -u openclaw docker run --rm alpine ping -c 2 8.8.8.8

# Check if MASQUERADE rules exist
sudo nft list table ip nat | grep -i masquerade

# If missing, restart Docker to recreate them
sudo systemctl restart docker
```

## Rootless Docker UID Mapping

Rootless Docker uses UID namespace remapping. The container runs as UID 1000, which maps to a different UID on the host.

Check your subuid base:
```bash
grep openclaw /etc/subuid
# Example output: openclaw:165536:65536
```

Calculate the host UID:
```
host_uid = subuid_base + container_uid - 1
host_uid = 165536 + 1000 - 1 = 166535
```

**Why the `-1`?** Rootless Docker's UID mapping reserves container UID 0 for the host user:
- Container UID 0 → Host user's actual UID (e.g., 1001 for `openclaw`)
- Container UID 1+ → Subordinate UID range from `/etc/subuid`

So container UID 1000 maps to `subuid_base + (1000 - 1)` because the subuid range starts at container UID 1, not 0. You can verify this mapping inside a container:
```bash
docker run --rm openclaw:local cat /proc/self/uid_map
#          0       1001          1    <- UID 0 maps to host user (1001)
#          1     165536      65536    <- UID 1+ maps to subuid range
```

| Container UID | Host UID | Calculation |
|---------------|----------|-------------|
| 1000 (node) | Varies | `subuid_base + 1000 - 1` |

Files must be owned by the calculated host UID for the container to read/write them.

### Fix Permissions

If you get permission denied errors after editing config:

```bash
# Get subuid base
grep openclaw /etc/subuid | awk -F: '{print $2}'  # e.g., 165536

# Calculate and fix ownership
SUBUID_BASE=$(grep openclaw /etc/subuid | awk -F: '{print $2}')
CONTAINER_UID=$(($SUBUID_BASE + 1000 - 1))
sudo chown -R $CONTAINER_UID:$CONTAINER_UID /home/openclaw/.openclaw

# Also ensure container can traverse the home directory
sudo setfacl -m u:$CONTAINER_UID:x /home/openclaw
```

**Note:** The container needs execute (traverse) permission on `/home/openclaw` to access the `.openclaw` subdirectory. The `setfacl` command grants this without changing ownership of the home directory.

### Debug Permissions

```bash
sudo -u openclaw docker run --rm -v /home/openclaw/.openclaw:/home/node/.openclaw openclaw:local sh -c "id && ls -la /home/node/.openclaw"
```

If directory shows `nobody:nogroup`, fix ownership using the calculation above.

## Troubleshooting

### Containers can't reach internet

```bash
# Test container connectivity
sudo -u openclaw docker run --rm alpine ping -c 2 8.8.8.8

# Check if nftables forward chain is blocking
sudo nft list chain inet filter forward

# Check if Docker's MASQUERADE rules exist
sudo nft list table ip nat | grep -i masquerade

# Restart Docker if missing
sudo systemctl restart docker
```

### Full Reset

If everything is broken:

```bash
# Stop and remove container
sudo -u openclaw docker rm -f openclaw-gateway

# Remove runtime config
sudo rm -rf /home/openclaw/.openclaw

# Re-run installer
cd /home/openclaw/rootless-docker-openclaw
sudo ./install.sh
```

## Files Reference

| Location | Purpose | Owner |
|----------|---------|-------|
| `/home/openclaw/openclaw/` | OpenClaw source (upstream) | openclaw |
| `/home/openclaw/rootless-docker-openclaw/` | This deployment repo | openclaw |
| `/home/openclaw/.openclaw/` | Runtime config and workspace | Mapped UID |
| `/home/openclaw/.openclaw/openclaw.json` | Gateway configuration | Mapped UID |

## Security Notes

- Firewall allows SSH (rate-limited), HTTP/HTTPS, and OpenClaw gateway port
- All other inbound traffic dropped
- Docker forward chain explicitly allows bridge interfaces
- Using `flush table inet filter` instead of `flush ruleset` to preserve Docker NAT
- OpenClaw runs as non-root user with UID namespace remapping

## Customization

To customize firewall rules, edit `configs/nftables.conf` before running `install.sh`. Common changes:

- Add additional allowed ports in the `input` chain
- Modify rate limiting rules
- Add custom logging rules
- Change the OpenClaw gateway port (default: 18789)

## Links

- [OpenClaw Docs](https://docs.openclaw.ai/)
- [Docker Rootless Mode](https://docs.docker.com/engine/security/rootless/)
- [Docker Install Guide](https://docs.openclaw.ai/install/docker)
