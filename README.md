# owncast-nginx-ssl
Debian installer for Owncast that makes it a service etc. Work in progress replacement for https://github.com/oszuidwest/nginx-rtmp-live

## Conventions
- Owncast has it's own user named `owncast`
- The working directory is `/var/lib/owncast`
- Configuration, logs and databases should be outside of the working directory for easy upgrades
- Owncast executable is linked to `/usr/bin/owncast`
- Let's encrypt and nginx are used as SSL and proxy (this isn't integrated yet)
