#!/usr/bin/env bash

# Clear the terminal
clear

# Download the functions library
if ! curl -s -o /tmp/functions.sh https://raw.githubusercontent.com/oszuidwest/bash-functions/refactor-user-check/common-functions.sh; then
  echo -e  "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
source /tmp/functions.sh

# Set color variables
set_colors

# Check if running as root
check_user_privileges privileged

# Check if this is Linux
is_this_linux

# Set the timezone
set_timezone Europe/Amsterdam

# Hi!
echo -e "${GREEN}⎎ Owncast set-up for ZuidWest TV${NC}\n\n"

# Ask for user input
ask_user "DO_UPDATES" "n" "Do you want to perform all OS updates? (y/n)" "y/n"
ask_user "APP_PORT" "8080" "Choose a port for the app to run on" "num"
ask_user "RTMP_PORT" "1935" "Choose a port for the RTMP intake" "num"
ask_user "STREAM_KEY" "hackme123" "Choose a stream key" "str"
ask_user "ADMIN_PASSWORD" "admin123" "Choose an admin password" "str"
ask_user "ENABLE_PROXY" "n" "Do you want a proxy serving traffic on port 80 and 443 with SSL? (y/n)" "y/n"

# Ask for additional input if the proxy is enabled
if [ "$ENABLE_PROXY" = "y" ]; then
  ask_user "SSL_HOSTNAME" "owncast.local" "Specify a hostname for the proxy (for example: owncast.example.org)" "host"
  ask_user "SSL_EMAIL" "root@localhost.local" "Specify an email address for SSL (for example: webmaster@example.org)" "email"
fi

# Run updates if DO_UPDATES is 'y'
if [ "$DO_UPDATES" = "y" ]; then
  update_os
fi

# Install necessary packages
install_packages silent ffmpeg unzip wget

# Create owncast user if not exists
if ! id -u owncast >/dev/null 2>&1; then 
  useradd -r -s /usr/sbin/nologin -d /opt/owncast -c "owncast daemon user" owncast
fi

# Installation variables
OWNCAST_VERSION="0.1.3"
OWNCAST_DIR="/opt/owncast"
OWNCAST_ZIP="/tmp/owncast.zip"
OWNCAST_SERVICE_FILE="/etc/systemd/system/owncast.service"

# Detect CPU architecture
ARCHITECTURE=$(uname -m)
case $ARCHITECTURE in
    x86_64) PACKAGE="owncast-${OWNCAST_VERSION}-linux-64bit.zip" ;;
    i686) PACKAGE="owncast-${OWNCAST_VERSION}-linux-32bit.zip" ;;
    aarch64) PACKAGE="owncast-${OWNCAST_VERSION}-linux-arm64.zip" ;;
    armv7l) PACKAGE="owncast-${OWNCAST_VERSION}-linux-arm7.zip" ;;
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

# Create log directory
install --directory --owner owncast --group owncast /var/log/owncast

# Create the service file
cat << EOF > $OWNCAST_SERVICE_FILE
[Unit]
Description=Owncast streaming service
[Service]
Type=simple
User=owncast
Group=owncast
WorkingDirectory=$OWNCAST_DIR
ExecStart=$OWNCAST_DIR/owncast -backupdir $OWNCAST_DIR/backup -database $OWNCAST_DIR/database -logdir /var/log/owncast -webserverport $APP_PORT -rtmpport $RTMP_PORT -streamkey $STREAM_KEY -adminpassword $ADMIN_PASSWORD
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Install and configure Caddy if SSL is enabled
if [ "$ENABLE_PROXY" = "y" ]; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list
  apt -qq -y update
  apt -qq -y install caddy
  cat <<EOF > /etc/caddy/Caddyfile
$SSL_HOSTNAME {
  reverse_proxy 127.0.0.1:$APP_PORT
  encode gzip
  tls $SSL_EMAIL
}
EOF
  systemctl enable caddy
  systemctl restart caddy
fi

# Enable and start owncast service
systemctl daemon-reload
systemctl enable owncast
systemctl restart owncast

# Verify the installation
if ! command -v ffmpeg >/dev/null; then
  echo -e "${RED}Install failed. ffmpeg is not installed.${NC}"
  exit 1
fi

if ! id -u owncast >/dev/null 2>&1; then
  echo -e "${RED}Install failed. User owncast does not exist.${NC}"
  exit 1
fi

echo -e "${GREEN}Installation checks passed. You can now start streaming.${NC}"
