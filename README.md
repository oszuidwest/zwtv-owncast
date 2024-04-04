# owncast-ssl-install
Debian/Ubuntu installer for Owncast that makes it a service etc. Replacement for https://github.com/oszuidwest/nginx-rtmp-live

## Conventions
- Owncast has it's own user named `owncast`
- The working directory is `/opt/owncast/`
- Configuration, logs and databases should be outside of the working directory for easy upgrades (only logs for now)
- Owncast executable is linked to `/usr/bin/owncast`
- Secure http proxy in port 80 and 443 with Let's Encrypt

## How to use
Set-up an empty server with Debian 12 or Ubuntu 22.04 and run this command as root:
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/owncast-ssl-install/main/install.sh)"`

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

It might also help to use the latest `ffmpeg` version instead of the one incldued in `apt`. Newer versions usually contain performance optimalisations.