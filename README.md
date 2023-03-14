# owncast-ssl-install
Debian installer for Owncast that makes it a service etc. Work in progress replacement for https://github.com/oszuidwest/nginx-rtmp-live

## Conventions
- Owncast has it's own user named `owncast`
- The working directory is `/opt/owncast/`
- Configuration, logs and databases should be outside of the working directory for easy upgrades (only logs for now)
- Owncast executable is linked to `/usr/bin/owncast`
- Let's encrypt and nginx are used as SSL and proxy (it's Caddy for now)

## How to use
Set-up an empty server with Debian 11 or Ubuntu 22.04 and run this command as root:
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/owncast-ssl-install/main/install.sh)"`

### Tune CPU for maximal performace
Video transcoding is an intensive process. To ensure the maximal stability, tune the CPU for maximal performance. Do the following:
- Install cpupower with `apt install linux-cpupower`
- Tune the CPU for performance `cpupower frequency-set -g performance`

To ensure it remains tuned for maximal performance after reboots, add a service file:
```
cat << EOF | sudo tee /etc/systemd/system/cpupower.service
[Unit]
Description=CPU powersave
[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower -c all frequency-set -g performance
[Install]
WantedBy=multi-user.target
EOF
```
