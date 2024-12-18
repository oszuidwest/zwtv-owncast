# zwtv-owncast

A Dockerized installer for Owncast, designed for [ZuidWest TV](https://www.zuidwesttv.nl/) and [Rucphen RTV](https://www.rucphenrtv.nl/). This project serves as a replacement for [nginx-rtmp-live](https://github.com/oszuidwest/nginx-rtmp-live).

## Conventions

- **Working Directory**: `/opt/owncast/`
- **Environment Configuration**:
  - The `.env` file is located in `/opt/owncast/` and includes all required environment variables:
    - `STREAM_KEY`
    - `ADMIN_PASSWORD`
    - `SSL_HOSTNAME`
- **Owncast Data**: Stored in the Docker volume `owncast_data`.
- **Caddy Data**: Stored in the Docker volume `owncast_caddy_data`.
- **Service Setup**:
  - Owncast and Caddy run as Docker containers.
  - Caddy: Acts as a secure reverse proxy with automatic SSL certificates managed by Let's Encrypt.
  - Owncast: Handles RTMP streaming and broadcasting.

This setup separates application logic (Docker containers) from persistent data (Docker volumes), ensuring easier upgrades and maintenance.

## How to Use

Choose your preferred method below ⬇️

### Guided Mode

1. Ensure your DNS settings are correctly configured for your domain.
2. Set up a fresh Debian or Ubuntu server with Docker and Docker Compose installed.
3. Run the following command as `root`:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/install.sh)"
   ```
4. The installer will set everything up for you automatically.

### I Know What I'm Doing

Download the `docker-compose.yml` and `.env.example` files from the repository and configure them as needed.

## Script for Bulk Configuration

The `postinstall.sh` script configures Owncast with custom settings, such as stream output variants. You will need to run the script manually. It sets these settings:

- 4 stream output variants (360p, 480p, 720p 1080p).
- Disable browser notifications.
- Hide viewer counts.
- Disable search indexing.
- Disable chat.
- Remove social handles and tags.

Run the script inside the directory your `.env` file is located.

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/postinstall.sh)"
   ```

### Tune CPU for maximal performace
Video transcoding is an intensive process. To ensure the maximal stability, tune the CPU for maximal performance. This only works on machines with physical cpus, not virtualized machines or containers. Do the following:
- Install cpupower with `apt install linux-tools-generic`
- Tune the CPU for performance `cpupower frequency-set -g performance`

To ensure it remains tuned for maximal performance after reboots, add a service file:
```
cat << EOF | sudo tee /etc/systemd/system/cpupower.service
[Unit]
Description=CPU tuning
[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
[Install]
WantedBy=multi-user.target
EOF
```
