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
    - `STREAM_NAME` (Optional: The name of the stream)
    - `LOGO_URL` (Optional: URL to the logo image for the stream)
    - `S3_ENDPOINT` (Optional: S3-compatible endpoint URL, e.g., for Cloudflare R2)
    - `S3_ACCESS_KEY` (Optional: Access key for S3 storage)
    - `S3_SECRET_KEY` (Optional: Secret key for S3 storage)
    - `S3_BUCKET` (Optional: Bucket name for S3 storage)
    - `S3_REGION` (Optional: Region for S3, default: auto)
    - `S3_ACL` (Optional: ACL for S3, default: private)
    - `S3_PATH_PREFIX` (Optional: Path prefix for S3)
    - `S3_FORCE_PATH_STYLE` (Optional: Force path style for S3, default: false)
    - `VIDEO_SERVING_ENDPOINT` (Optional: Custom endpoint for serving videos)
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

To upgrade an existing installation, simply re-run the installer. It will detect your existing configuration and offer to preserve it.

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
- Set stream name (if configured).
- Set logo (if configured).
- Configure S3 storage (if configured).
- Set video serving endpoint (if configured).

Run this command to apply the settings:

   ```bash
   docker run --rm \
    --volume /opt/owncast/.env:/.env \
    --network owncast_backend \
    -e BASE_URL=http://owncast:8080 \
    alpine sh -c "apk add --no-cache bash curl && bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/postinstall.sh)\""
   ```

_If you've changed the network or container name, update the command_

## S3 Storage Configuration (Optional)

Owncast supports S3-compatible storage for storing livestream segments and playlists (HLS format). This is particularly useful for Owncast because:

- **Scalability and Reliability**: S3 services handle large-scale storage and provide redundancy, ensuring your livestreams are available even during high traffic or for on-demand playback.
- **Cost Efficiency**: Many S3 providers offer competitive pricing, and integrating with a CDN (like Cloudflare) reduces bandwidth costs from your server.

This is optional and can be configured during installation or by adding the variables to your `.env` file.

### Generic S3 Setup
To use any S3-compatible service (e.g., AWS S3, MinIO), set the following in your `.env` file:
- `S3_ENDPOINT`: The endpoint URL (e.g., `https://s3.amazonaws.com` for AWS).
- `S3_ACCESS_KEY`: Your access key.
- `S3_SECRET_KEY`: Your secret key.
- `S3_BUCKET`: The bucket name.
- Other variables like `S3_REGION`, `S3_ACL`, etc., as needed.

### Cloudflare R2 Setup
Cloudflare R2 is a cost-effective, S3-compatible storage service ideal for Owncast, as it integrates seamlessly with Cloudflare's CDN for optimal performance and cost-effectiveness. At the time of writing, R2 offers a generous free tier (10 GB storage, 1 million Class A operation/month, 10 million Class B operations/month), making it perfect for small to medium streams without incurring costs.

To configure it:

1. **Create an R2 Bucket**:
   - Log in to your Cloudflare dashboard.
   - Go to R2 > Create bucket (e.g., name it `your-owncast-bucket`).

2. **Create an API Token**:
   - Go to My Profile > API Tokens > Create Token.
   - Use the "Workers R2 Storage Write" permission group, scoped to your account.
   - Note the Access Key ID and Secret Access Key.

3. **Set Up DNS and Custom Domain (Optional but Recommended)**:
   - In R2, set a custom domain for the bucket to enable direct access (e.g., `media.yourdomain.com`).

4. **Configure Caching (for Performance and Cost Savings)**:
   - In Cloudflare Rulesets (under Rules > Page Rules or Custom Rules), create rules to cache media files. This ensures that repeated requests for the same video segments are served from Cloudflare's edge network instead of hitting your R2 bucket directly, reducing request counts and keeping usage well within R2's free tier.
     - Cache all requests to `media.yourdomain.com` with edge TTL of 3600s and browser TTL of 3600s.
     - Special rule for `.m3u8` (playlists): Edge TTL 10s, browser TTL 10s, exclude query strings. Owncast includes a cache-busting query string in playlist URLs to ensure viewers always get the latest playlist, but we want to ignore those in Cloudflare, otherwise the caching has no effect. The duration is set low to ensure timely updates of the playlist.
     - Special rule for `.ts` (segments): Edge TTL 3600s, browser TTL 3600s.

5. **Environment Variables for R2**:
   - `S3_ENDPOINT`: `https://<your-account-id>.r2.cloudflarestorage.com` (find your account ID in Cloudflare dashboard).
   - `S3_ACCESS_KEY`: Your R2 access key.
   - `S3_SECRET_KEY`: Your R2 secret key.
   - `S3_BUCKET`: Your bucket name (e.g., `your-owncast-bucket`).
   - `S3_REGION`: `auto`.
   - `S3_ACL`: `private`.
   - `S3_FORCE_PATH_STYLE`: `false`.
   - `VIDEO_SERVING_ENDPOINT`: `https://media.yourdomain.com` (if using custom domain).

After setting these, run the postinstall script to apply the configuration. Livestream segments and playlists will be stored in R2, and Owncast will serve them via the configured endpoint, leveraging Cloudflare's caching to minimize direct bucket hits and stay within the free tier.

### Tune CPU for maximal performace
Video transcoding is an intensive process. To ensure the maximal stability, tune the CPU for maximal performance. This only works on machines with physical cpus, not virtualized machines or containers. Do the following:

1. Install cpupower: `apt install linux-cpupower`
2. Tune the CPU for performance: `cpupower frequency-set -g performance`

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
3. Reload the systemd configuration to make the new service recognizable: `systemctl daemon-reload`
4. Enable the service to ensure it starts automatically at boot: `systemctl start cpupower.service`