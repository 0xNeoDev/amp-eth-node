# Systemd Service (Linux Production)

For production Linux servers, run amp-eth-node as a systemd service to ensure automatic startup on boot and clean shutdown handling.

## Install

Copy the unit file to systemd:

```bash
sudo cp docs/amp-eth-node.service /etc/systemd/system/
sudo systemctl daemon-reload
```

Edit the service file to set `WorkingDirectory` and `User` for your environment:

```bash
sudo systemctl edit amp-eth-node
```

## Usage

```bash
# Enable on boot
sudo systemctl enable amp-eth-node

# Start
sudo systemctl start amp-eth-node

# Check status
sudo systemctl status amp-eth-node

# View logs
journalctl -u amp-eth-node -f

# Stop (graceful — sends SIGTERM to docker compose)
sudo systemctl stop amp-eth-node
```

## Unit File

The unit file uses `docker compose` directly. It waits for `docker.service` to be ready and sets a generous stop timeout (5 minutes) to allow Reth to flush state to disk on shutdown.
