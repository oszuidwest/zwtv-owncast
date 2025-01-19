# zwtv-owncast

A Dockerized installer for Owncast, designed for [ZuidWest TV](https://www.zuidwesttv.nl/), [Rucphen RTV](https://www.rucphenrtv.nl/) and [BredaNu](https://www.bredanu.nl/). This project serves as a replacement for [nginx-rtmp-live](https://github.com/oszuidwest/nginx-rtmp-live).

## Conventions

- **Working Directory**: `/opt/owncast/`
- **Environment Configuration**:
  - The `.env` file is located in the `/opt/owncast/` directory and contains all the necessary environment variables:
    - `STREAM_KEY` (RTMP key for Owncast)
    - `ADMIN_PASSWORD` (Password for the Owncast admin interface)
    - `SSL_HOSTNAME` (The server’s hostname (without including `http://` or `https://`))
    - `ADMIN_IPS` (One or more IP addresses that should be permitted to access the admin interface, separated by spaces)
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
5. As the last step it'll ask you if you want to start the services. If you choose to do so, it'll also ask you if you want to run the postinstall script.

### I Know What I'm Doing

Download the `docker-compose.yml`, `.env.example` and `Caddyfile` files from the repository and configure them as needed.

## Script for Bulk Configuration

The `postinstall.sh` script configures Owncast with custom settings, such as stream output variants. The install script asks you if you want to run this script. If you choose not to do so, and want to do it manually later, you can do so with the command below. It sets these settings:

- 4 stream output variants (360p, 480p, 720p 1080p).
- Disable browser notifications.
- Hide viewer counts.
- Disable search indexing.
- Disable chat.
- Remove social handles and tags.

Run this command to apply the settings:

   ```bash
   docker run --rm \
    --volume /opt/owncast/.env:/.env \
    --network owncast_backend \
    -e BASE_URL=http://owncast:8080 \
    alpine sh -c "apk add --no-cache bash curl && bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/postinstall.sh)\""
   ```

_If you've changed the network or container name, update the command_

### Tune CPU for maximal performace
Video transcoding is an intensive process. To ensure the maximal stability, tune the CPU for maximal performance. This only works on machines with physical cpus, not virtualized machines or containers. Do the following:
- Install cpupower with `apt install linux-cpupower`
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
