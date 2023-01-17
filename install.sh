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
WEB_PORT=${WEB_PORT:-8080}
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

#     BIG     #
#     WIP     #
#     FROM     #
#     HERE     #

# Add the user owncast
useradd owncast --system --shell /usr/sbin/nologin --home /var/lib/owncast --comment "owncast daemon user"

# Create essential dirs
install --directory --owner owncast --group owncast /var/lib/owncast

# Install packages
apt --quiet --quiet --yes install ffmpeg nginx-light certbot >/dev/null 2>&1

# Verify installation. Set a flag to track whether any checks failed
INSTALL_FAILED=false

# Check the installation of ffmpeg
if ! command -v ffmpeg &> /dev/null; then
  echo -e "\033[31mWe could not verify the correctness of the installation. ffmpeg is not installed.\033[0m"
  INSTALL_FAILED=true
fi

# check if the user "owncast" exists
if ! id -u owncast >/dev/null 2>&1; then
  echo -e "\033[31mWe could not verify the correctness of the installation. User owncast doesn't exist.\033[0m"
  INSTALL_FAILED=true
fi

# If any checks failed, exit with an error code
if $INSTALL_FAILED; then
  exit 1
else
  # All checks passed, display success message
  echo -e "\033[32mInstallation checks passed. You can now start streaming.\033[0m"
fi