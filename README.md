# zwtv-owncast

A Dockerized installer for Owncast, designed for **ZuidWest TV** and **Rucphen RTV**. This project serves as a replacement for [nginx-rtmp-live](https://github.com/oszuidwest/nginx-rtmp-live).

## Conventions

- **Working Directory**: `/opt/owncast/`
- **Environment Configuration**:
  - The `.env` file is located in `/opt/owncast/` and includes all required environment variables:
    - `STREAM_KEY`
    - `ADMIN_PASSWORD`
    - `SSL_HOSTNAME`
    - `SSL_EMAIL`
- **Owncast Data**: Stored in the Docker volume `owncast_data`.
- **Caddy Data**: Stored in the Docker volume `owncast_caddy_data`.
- **Service Setup**:
  - Owncast and Caddy run as Docker containers.
  - **Caddy**: Acts as a secure reverse proxy with automatic SSL certificates managed by Let's Encrypt.
  - **Owncast**: Handles RTMP streaming and broadcasting.

This setup separates application logic (Docker containers) from persistent data (Docker volumes), ensuring easier upgrades and maintenance.

## How to Use

Choose your preferred method below ⬇️

### Easy Mode

1. Ensure your DNS settings are correctly configured for your domain.
2. Set up a fresh Debian or Ubuntu server with **Docker** and **Docker Compose** installed.
3. Run the following command as `root`:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/install.sh)"
   ```
4. The installer will set everything up for you automatically.

### Advanced Mode: I Know What I'm Doing

Download the `docker-compose.yml` and `.env.example` files from the repository and configure them as needed.

## Script for Bulk Configuration Adjustments

The `postinstall.sh` script allows you to configure Owncast with custom settings, such as stream output variants and disabling search indexing. You will need to run the script manually.

**Applied Configurations:**
- Set up 4 stream output variants.
- Disable browser notifications.
- Hide viewer counts.
- Disable search indexing.
- Disable chat.
- Remove social handles and tags.

Run the script after installation to apply these adjustments.

## Optimize CPU for Maximum Performance

Video transcoding is CPU-intensive, so tuning your CPU for maximum performance can significantly improve stability. **Note:** This optimization only works on physical machines, not on virtualized servers or within containers.

### Steps:
1. Install `cpupower`:
   ```bash
   apt install linux-tools-generic
   ```
2. Set the CPU to performance mode:
   ```bash
   cpupower frequency-set -g performance
   ```

### Persist CPU Settings Across Reboots
To ensure the CPU remains tuned for maximum performance after a reboot, set up a systemd service:

```bash
cat << EOF | sudo tee /etc/systemd/system/cpupower.service
[Unit]
Description=CPU Performance Tuning

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance

[Install]
WantedBy=multi-user.target
EOF
```

3. Enable and start the service:
   ```bash
   sudo systemctl enable cpupower.service
   sudo systemctl start cpupower.service
   ```
