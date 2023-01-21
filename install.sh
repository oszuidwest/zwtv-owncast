# BIG WORK IN PROGRESS

# Start with a clean terminal
clear

# Check if the user is root
if [ "$(id -u)" != "0" ]; then
  echo "You must be root to execute the script. Exiting."
  exit 1
fi

# Function that checks and creates dirs
check_and_fix_dirs() {
  for dir_path in "$@"
  do
    if [ -d "$dir_path" ]; then
      if [ "$(stat -c '%U:%G' $dir_path)" == "owncast:owncast" ]; then
        : # Do nothing
      else
        chown owncast:owncast $dir_path
      fi
    else
      install --directory --owner owncast --group owncast $dir_path
    fi
  done
}

# Ask for input for variables
read -p "Do you want to perform all OS updates? (default: y) " DO_UPDATES
read -p "Choose a port for the web interface (default: 8080) " WEB_PORT
read -p "Choose a port for the rtmp intake (default: 1935) " RTMP_PORT
read -p "Choose a stream key (default: xyz987) " STREAM_KEY

# If there is an empty string, use the default value
DO_UPDATES=${DO_UPDATES:-y}
WEB_PORT=${WEB_PORT:-8080}
RTMP_PORT=${RTMP_PORT:-1935}
STREAM_KEY=${STREAM_KEY:-xyz987}

# Perform validation on input
if [ "$DO_UPDATES" != "y" ] && [ "$DO_UPDATES" != "n" ]; then
  echo "Invalid input for DO_UPDATES. Only 'y' or 'n' are allowed."
  exit 1
fi

if ! [[ "$WEB_PORT" =~ ^[0-9]+$ ]] || [ "$WEB_PORT" -lt 1 ] || [ "$WEB_PORT" -gt 65535 ]; then
  echo "Invalid port number for WEB_PORT. Please enter a valid port number (1 to 65535)."
  exit 1
fi

if ! [[ "$RTMP_PORT" =~ ^[0-9]+$ ]] || [ "$RTMP_PORT" -lt 1 ] || [ "$RTMP_PORT" -gt 65535 ]; then
  echo "Invalid port number for RTMP_PORT. Please enter a valid port number (1 to 65535)."
  exit 1
fi

# Check if the DO_UPDATES variable is set to 'y'
if [ "$DO_UPDATES" = "y" ]; then
  # If it is, run the apt update, upgrade, and autoremove commands with the --yes flag to automatically answer yes to prompts
  apt --quiet --quiet --yes update >/dev/null 2>&1
  apt --quiet --quiet --yes upgrade >/dev/null 2>&1
  apt --quiet --quiet --yes autoremove >/dev/null 2>&1
fi

# Install packages
apt --quiet --quiet --yes install unzip ffmpeg nginx-light certbot >/dev/null 2>&1

# Add the user owncast if it doesn't exist
if ! id -u owncast > /dev/null 2>&1; then 
  useradd owncast --system --shell /usr/sbin/nologin --home /var/lib/owncast --comment "owncast daemon user"
fi

# Check if the working directory exists
check_and_fix_dirs "/var/lib/owncast" "/var/log/owncast" 

#     BIG     #
#     WIP     #
#     FROM     #
#     HERE     #

# Download and install Owncast (harcoded for now)
wget "https://github.com/owncast/owncast/releases/download/v0.0.13/owncast-0.0.13-linux-64bit.zip" -O /var/lib/owncast/owncast.zip
unzip /var/lib/owncast/owncast.zip -C /var/lib/owncast/
rm /var/lib/owncast/owncast.zip
chmod +x /var/lib/owncast/owncast
ln -s /var/lib/owncast/owncast /usr/bin/

# Create the service file
cat << EOF > /etc/systemd/system/owncast.service
  [Unit]
  Description=Owncast streaming service
  [Service]
  Type=simple
  User=owncast
  Group=owncast
  WorkingDirectory=/var/lib/owncast
  ExecStart=/usr/bin/owncast -backupdir /var/lib/owncast/backup -database /var/lib/owncast/database -logdir /var/log/owncast -webserverport $WEB_PORT -rtmpport $RTMP_PORT -streamkey $STREAM_KEY
  Restart=on-failure
  RestartSec=5
  [Install]
  WantedBy=multi-user.target
EOF

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
