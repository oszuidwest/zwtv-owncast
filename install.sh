#!/usr/bin/env bash

# Files to download
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/v2/common-functions.sh"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/docker-compose.yml"
CADDYFILE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/Caddyfile"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/.env.example"

# Constants
FUNCTIONS_LIB_PATH=$(mktemp)
INSTALL_DIR="/opt/owncast"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
CADDY_FILE="${INSTALL_DIR}/Caddyfile"
ENV_FILE="${INSTALL_DIR}/.env"

# Clean up temporary file on exit
trap 'rm -f "$FUNCTIONS_LIB_PATH"' EXIT

# Download the functions library
if ! curl -s -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
# shellcheck source=/dev/null
source "$FUNCTIONS_LIB_PATH"

# Set color variables
set_colors

# Check if the script is running as root
assert_user_privileged "root"

# Ensure the script is running on a supported platform (Linux, 64-bit)
assert_os_linux
assert_os_64bit

# Check if docker is installed
assert_tool "docker"

# Clear the terminal
clear

# Display Banner
cat << "EOF"
 ______   _ ___ ______        _______ ____ _____   _______     __
|__  / | | |_ _|  _ \ \      / / ____/ ___|_   _| |_   _\ \   / /
  / /| | | || || | | \ \ /\ / /|  _| \___ \ | |     | |  \ \ / / 
 / /_| |_| || || |_| |\ V  V / | |___ ___) || |     | |   \ V /  
/____|\___/|___|____/  \_/\_/  |_____|____/ |_|     |_|    \_/   
EOF

# Greet the user
echo -e "${GREEN}⎎ Dockerized Owncast for ZuidWest TV${NC}\n\n"

# Ask for user input
prompt_user "DO_UPDATES" "y" "Perform OS updates? (y/n)" "y/n"
prompt_user "STREAM_KEY" "hackme123" "Owncast stream key" "str"
prompt_user "ADMIN_PASSWORD" "admin123" "Owncast admin password" "str"
prompt_user "ADMIN_IPS" "0.0.0.0/0" "IPs allowed to access Owncast admin (space-separated, 0.0.0.0/0 = allow all)" "str"
prompt_user "SSL_HOSTNAME" "owncast.local" "Hostname for SSL proxy (e.g. owncast.example.org)" "host"

# Set system timezone
set_timezone Europe/Amsterdam

# Perform OS updates if requested by the user
if [ "$DO_UPDATES" == "y" ]; then
  apt_update --silent
fi

# Create the installation directory
echo -e "${BLUE}►► Creating installation directory: ${INSTALL_DIR}${NC}"
mkdir -p "${INSTALL_DIR}"

# Download docker-compose.yml
echo -e "${BLUE}►► Downloading docker-compose.yml"
if ! curl -s -o "${COMPOSE_FILE}" "${DOCKER_COMPOSE_URL}"; then
  echo -e "${RED}*** Failed to download docker-compose.yml. Please check your network connection! ***${NC}"
  exit 1
fi

# Download Caddyfile
echo -e "${BLUE}►► Downloading Caddyfile"
if ! curl -s -o "${CADDY_FILE}" "${CADDYFILE_URL}"; then
  echo -e "${RED}*** Failed to download Caddyfile. Please check your network connection! ***${NC}"
  exit 1
fi

# Download the .env.example file
echo -e "${BLUE}►► Downloading .env.example and renaming it to .env${NC}"
if ! curl -s -o "${ENV_FILE}" "${ENV_EXAMPLE_URL}"; then
  echo -e "${RED}*** Failed to download .env.example. Please check your network connection! ***${NC}"
  exit 1
fi

# Fill in the .env file with user-provided values
echo -e "${BLUE}►► Filling in the .env file with provided values${NC}"
sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ADMIN_PASSWORD}|g" "${ENV_FILE}"
sed -i "s|ADMIN_IPS=.*|ADMIN_IPS=${ADMIN_IPS}|g" "${ENV_FILE}"
sed -i "s|STREAM_KEY=.*|STREAM_KEY=${STREAM_KEY}|g" "${ENV_FILE}"
sed -i "s|SSL_HOSTNAME=.*|SSL_HOSTNAME=${SSL_HOSTNAME}|g" "${ENV_FILE}"

# Restrict permissions on .env file (contains credentials)
chmod 600 "${ENV_FILE}"

# Instructions for next steps
echo -e "\n\n${GREEN}✓ Installation set up at ${INSTALL_DIR}${NC}"
echo -e "${YELLOW}The .env file has been populated with the values you provided.${NC}"

# Start Owncast and Caddy
prompt_user "START_OWNCAST" "y" "Start Owncast and Caddy now? (y/n)" "y/n"
if [ "$START_OWNCAST" == "y" ]; then
  cd "${INSTALL_DIR}" || exit
  docker compose up -d

  prompt_user "RUN_POSTINSTALL" "y" "Run the postinstall script? (y/n)" "y/n"

  # Run the postinstall script if requested by the user
  if [ "$RUN_POSTINSTALL" == "y" ]; then
    echo -e "${BLUE}►► Running postinstall script${NC}"
    docker run --rm \
      --volume /opt/owncast/.env:/.env \
      --network owncast_backend \
      -e BASE_URL=http://owncast:8080 \
      alpine sh -c "apk add --no-cache bash curl && bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/postinstall.sh)\""
  fi
else
  echo -e "${YELLOW}To start Owncast and Caddy, navigate to ${INSTALL_DIR} and run: docker compose up -d${NC}"
fi
