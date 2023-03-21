#!/bin/bash

# Start with a clean terminal
clear

# Check if the user is root
if [ "$(id -u)" != "0" ]; then
  echo "You must be root to execute the script. Exiting."
  exit 1
fi

# Ask for input for variables
read -rp "Do you want to perform all OS updates? (default: y): " -i "y" DO_UPDATES
read -rp "Choose a port for the app to run on (default: 8080): " -i "8080" APP_PORT
read -rp "Choose a port for the rtmp intake (default: 1935): " -i "1935" RTMP_PORT
read -rp "Choose a stream key (default: xyz987): " -i "xyz987" STREAM_KEY
read -rp "Do you want a proxy serving traffic on port 80 and 443 with ssl? (default: n): " -i "n" ENABLE_PROXY

# Only ask for the log file and log rotation if ENABLE_PROXY is 'y'
if [ "$ENABLE_PROXY" = "y" ]; then
  read -rp "Specify a hostname for the proxy (for example: live.zuidwesttv.nl): " SSL_HOSTNAME
  read -rp "Specify an e-mailadress for SSL (for example: techniek@zuidwesttv.nl): " SSL_EMAIL
fi

# Perform validation on input
if [ "$DO_UPDATES" != "y" ] && [ "$DO_UPDATES" != "n" ]; then
  echo "Invalid input for DO_UPDATES. Only 'y' or 'n' are allowed."
  exit 1
fi

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]; then
  echo "Invalid port number for APP_PORT. Please enter a valid port number (1 to 65535)."
  exit 1
fi

if ! [[ "$RTMP_PORT" =~ ^[0-9]+$ ]] || [ "$RTMP_PORT" -lt 1 ] || [ "$RTMP_PORT" -gt 65535 ]; then
  echo "Invalid port number for RTMP_PORT. Please enter a valid port number (1 to 65535)."
  exit 1
fi

if [ "$ENABLE_PROXY" != "y" ] && [ "$ENABLE_PROXY" != "n" ]; then
  echo "Invalid input for ENABLE_PROXY. Only 'y' or 'n' are allowed."
  exit 1
fi

# Only validate these if the proxy is enabled
if [ "$ENABLE_PROXY" = "y" ]; then
  if [[ ! "$SSL_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
    echo "Invalid hostname. Only bare hostnames are allowed. No https:// in front of it please"
    exit 1
  fi

  if [[ ! "$SSL_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "Invalid e-mailadress"
    exit 1
  fi
fi

# Check if the DO_UPDATES variable is set to 'y'
if [ "$DO_UPDATES" = "y" ]; then
  # If it is, run the apt update, upgrade, and autoremove commands with the --yes flag to automatically answer yes to prompts
  apt --quiet --quiet --yes update >/dev/null 2>&1
  apt --quiet --quiet --yes upgrade >/dev/null 2>&1
  apt --quiet --quiet --yes autoremove >/dev/null 2>&1
fi

# Install packages
apt --quiet --quiet --yes install ffmpeg unzip >/dev/null 2>&1

# Add the user owncast if it doesn't exist
if ! id -u owncast > /dev/null 2>&1; then 
  useradd owncast --system --shell /usr/sbin/nologin --home /opt/owncast --comment "owncast daemon user"
fi

#     BIG     #
#     WIP     #
#     FROM     #
#     HERE     #

# Installation variables
OWNCAST_VERSION="0.0.13"
OWNCAST_DIR="/opt/owncast"
OWNCAST_ZIP="/tmp/owncast.zip"
OWNCAST_SERVICE_FILE="/etc/systemd/system/owncast.service"

# Detect CPU architecture
ARCHITECTURE=$(uname -m)
case $ARCHITECTURE in
    x86_64)
        PACKAGE="owncast-${OWNCAST_VERSION}-linux-64bit.zip"
        ;;
    i686)
        PACKAGE="owncast-${OWNCAST_VERSION}-linux-32bit.zip"
        ;;
    aarch64)
        PACKAGE="owncast-${OWNCAST_VERSION}-linux-arm64.zip"
        ;;
    armv7l)
        PACKAGE="owncast-${OWNCAST_VERSION}-linux-arm7.zip"
        ;;
    *)
        echo "Unsupported CPU architecture: $ARCHITECTURE"
        exit 1
        ;;
esac

# Download and install Owncast
wget "https://github.com/owncast/owncast/releases/download/v${OWNCAST_VERSION}/${PACKAGE}" -O $OWNCAST_ZIP
unzip -o $OWNCAST_ZIP -d $OWNCAST_DIR
rm $OWNCAST_ZIP
chown -R owncast:owncast $OWNCAST_DIR
chmod +x $OWNCAST_DIR/owncast

# Create log dir
install --directory --owner owncast --group owncast /var/log/owncast

# Create the service file
cat << EOF > /etc/systemd/system/owncast.service
  [Unit]
  Description=Owncast streaming service
  [Service]
  Type=simple
  User=owncast
  Group=owncast
  WorkingDirectory=/opt/owncast
  ExecStart=/opt/owncast/owncast -backupdir /opt/owncast/backup -database /opt/owncast/database -logdir /var/log/owncast -webserverport $APP_PORT -rtmpport $RTMP_PORT -streamkey $STREAM_KEY
  Restart=on-failure
  RestartSec=5
  [Install]
  WantedBy=multi-user.target
EOF

# Install Caddy
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy

# Configure Caddy for HTTPS proxying
if [ -n "$SSL_HOSTNAME" ] && [ -n "$SSL_EMAIL" ]; then

  cat >/etc/caddy/Caddyfile <<EOF
  ${SSL_HOSTNAME} {
    redir /live/zwtv.m3u8 /hls/stream.m3u8 permanent
    reverse_proxy 127.0.0.1:$APP_PORT
    encode gzip
    tls ${SSL_EMAIL}
  }
EOF
  # Start Caddy
  systemctl enable caddy
  systemctl restart caddy
else
  echo -e "\033[1mOWNCAST INSTALL WARNING: \033[0mServer hostname and/or email not specified.  Skipping Caddy/SSL configuration."
fi

# Use a robots.txt file to prevent Search Engines from indexing this instance
[[ ! -f /opt/owncast/webroot/robots.txt ]] && echo -e "User-agent: *\nDisallow: /" > /opt/owncast/webroot/robots.txt

# Enable service
systemctl daemon-reload
systemctl enable owncast.service
systemctl restart owncast

# Verify installation. Set a flag to track whether any checks failed
INSTALL_FAILED=false

# Check the installation of ffmpeg
if ! command -v ffmpeg &> /dev/null; then
  echo -e "\033[31mInstallation failed. ffmpeg is not installed.\033[0m"
  INSTALL_FAILED=true
fi

# check if the user "owncast" exists
if ! id -u owncast >/dev/null 2>&1; then
  echo -e "\033[31mInstallation failed. User owncast doesn't exist.\033[0m"
  INSTALL_FAILED=true
fi

# If any checks failed, exit with an error code
if $INSTALL_FAILED; then
  exit 1
else
  # All checks passed, display success message
  echo -e "\033[32mInstallation checks passed. You can now start streaming.\033[0m"
fi
