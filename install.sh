#!/bin/bash

# Clear the terminal
clear

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
  echo -e "${RED}This script must be run as root. Please run 'sudo su' first.${NC}"
  exit 1
fi

# Ask for user input
read -rp "Do you want to perform all OS updates? (y/n): " DO_UPDATES
read -rp "Choose a port for the app to run on (for example: 8080): " APP_PORT
read -rp "Choose a port for the RTMP intake (for example: 1935): " RTMP_PORT
read -rp "Choose a stream key (for example: hackme123): " STREAM_KEY
read -rp "Choose an admin password (for example: admin123): " ADMIN_PASSWORD
read -rp "Do you want a proxy serving traffic on port 80 and 443 with SSL? (y/n): " ENABLE_PROXY

# Ask for additional input if the proxy is enabled
if [ "$ENABLE_PROXY" = "y" ]; then
  read -rp "Specify a hostname for the proxy (for example: owncast.example.org): " SSL_HOSTNAME
  read -rp "Specify an email address for SSL (for exampleL webmaster@example.org): " SSL_EMAIL
fi

# Input validation
if ! [[ "$DO_UPDATES" =~ ^(y|n)?$ ]]; then
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

if ! [[ "$ENABLE_PROXY" =~ ^(y|n)?$ ]]; then
  echo "Invalid input for ENABLE_PROXY. Only 'y' or 'n' are allowed."
  exit 1
fi

# Additional validation for proxy inputs
if [ "$ENABLE_PROXY" = "y" ]; then
  if ! [[ "$SSL_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
    echo "Invalid hostname. Only bare hostnames are allowed. No https:// in front of it please"
    exit 1
  fi

  if ! [[ "$SSL_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "Invalid e-mail address."
    exit 1
  fi
fi

# Run updates if DO_UPDATES is 'y'
if [ "$DO_UPDATES" = "y" ]; then
  apt -qq -y update > /dev/null 2>&1
  apt -qq -y full-upgrade > /dev/null 2>&1
  apt -qq -y autoremove > /dev/null 2>&1
fi

# Install necessary packages
apt -qq -y install ffmpeg unzip >/dev/null 2>&1

# Create owncast user if not exists
if ! id -u owncast >/dev/null 2>&1; then 
  useradd -r -s /usr/sbin/nologin -d /opt/owncast -c "owncast daemon user" owncast
fi

# Installation variables
OWNCAST_VERSION="0.1.0"
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
  echo -e "\033[31mffmpeg is not installed.\033[0m"
  exit 1
fi
if ! id -u owncast >/dev/null 2>&1; then
  echo -e "\033[31mUser owncast does not exist.\033[0m"
  exit 1
fi

echo -e "\033[32mInstallation checks passed. You can now start streaming.\033[0m"