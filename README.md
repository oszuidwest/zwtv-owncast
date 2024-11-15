# zwtv-owncast

Dockerized installer for Owncast. Used for ZuidWest TV and Rucphen RTV. Replacement for [nginx-rtmp-live](https://github.com/oszuidwest/nginx-rtmp-live).

## Conventions

- **Working Directory**: `/opt/owncast/`
- **Environment Configuration**:
  - `.env` file located in `/opt/owncast/`, populated with necessary environment variables (`STREAM_KEY`, `ADMIN_PASSWORD`, `SSL_HOSTNAME`, `SSL_EMAIL`).
- **Owncast Data**: Stored in Docker volume `owncast_data`.
- **Caddy Data**: Stored in Docker volume `owncast_caddy_data`.
- **Service Setup**:
  - Owncast and Caddy run as Docker containers.
  - Caddy provides a secure reverse proxy with automatic SSL using Let's Encrypt.
  - Owncast handles RTMP streaming and broadcasting.

This setup ensures separation of application logic (via Docker containers) and persistent data (via Docker volumes), allowing for easy upgrades and maintenance.

## How to Use

### Easy mode:
1. Ensure DNS settings are properly configured for your domain.
2. Set up an empty Debian or Ubuntu server with Docker and Docker Compose.
3. Run the following command as root:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/install.sh)"
   ```
4. Everything will be installed for you.

### I know what i'm doing:
Just download the `docker-compose.yml` and `.env.example` file and have fun.

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