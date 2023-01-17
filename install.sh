# BIG WORK IN PROGRESS

# Start with a clean terminal
clear

# Are we root?
if [ "$(id -u)" != "0" ]; then
  echo "You must be root to execute the script. Exiting."
  exit 1
fi

# Ask for input for variables
read -p "Do you want to perform all OS updates? (default: y) " DO_UPDATES
read -p "Choose a port for the web interface (default: 8080) " WEB_PORT
read -p "Choose a port for the rtmp intake (default: 1935) " RTMP_PORT

# If there is an empty string, use the default value
DO_UPDATES=${DO_UPDATES:-y}
WEB_PORT=${WEB_PORT:-80}
RTMP_PORT=${RTMP_PORT:-1935}

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

# BIG
# WIP
# FROM
# HERE

useradd owncast --system --shell /usr/sbin/nologin --home /var/lib/owncast --comment "owncast daemon user"
install --directory --owner owncast --group owncast /var/lib/owncast
apt install ffmpeg nginx-light certbot -y