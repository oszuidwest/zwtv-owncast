#!/usr/bin/env bash

# Files to download
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/refs/heads/dockerize/docker-compose.yml"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/refs/heads/dockerize/.env.example"

# Constants
FUNCTIONS_LIB_PATH="/tmp/functions.sh"
INSTALL_DIR="/opt/owncast"
ENV_FILE="${INSTALL_DIR}/.env"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

# Remove old functions library and download the latest version
rm -f "$FUNCTIONS_LIB_PATH"
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
check_user_privileges privileged

# Ensure the script is running on a supported platform (Linux)
is_this_linux

# Check if docker is installed 
require_tool "docker"

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
ask_user "DO_UPDATES" "y" "Do you want to perform all OS updates? (y/n)" "y/n"
ask_user "STREAM_KEY" "hackme123" "Pick a stream key for Owncast" "str"
ask_user "ADMIN_PASSWORD" "admin123" "Choose an admin password for Owncast" "str"
ask_user "SSL_HOSTNAME" "owncast.local" "Specify a hostname for the proxy (for example: owncast.example.org)" "host"
ask_user "SSL_EMAIL" "root@localhost.local" "Specify an email address for SSL (for example: webmaster@example.org)" "email"

# Set system timezone
set_timezone Europe/Amsterdam

# Perform OS updates if requested by the user
if [ "$DO_UPDATES" == "y" ]; then
  update_os silent
fi

# Create the installation directory
echo -e "${BLUE}►► Creating installation directory: ${INSTALL_DIR}${NC}"
mkdir -p ${INSTALL_DIR}

# Download docker-compose.yml
echo -e "${BLUE}►► Downloading docker-compose.yml"
if ! curl -s -o "${COMPOSE_FILE}" "${DOCKER_COMPOSE_URL}"; then
  echo -e "${RED}*** Failed to download docker-compose.yml. Please check your network connection! ***${NC}"
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
sed -i "s|STREAM_KEY=.*|STREAM_KEY=${STREAM_KEY}|g" "${ENV_FILE}"
sed -i "s|SSL_HOSTNAME=.*|SSL_HOSTNAME=${SSL_HOSTNAME}|g" "${ENV_FILE}"
sed -i "s|SSL_EMAIL=.*|SSL_EMAIL=${SSL_EMAIL}|g" "${ENV_FILE}"

# Instructions for next steps
echo -e "${GREEN}Installation directory set up at ${INSTALL_DIR}${NC}"
echo -e "${YELLOW}The .env file has been populated with the values you provided.${NC}"
echo -e "${YELLOW}To start Owncast and Caddy, navigate to ${INSTALL_DIR} and run:${NC}"
echo -e "${CYAN}docker-compose up -d${NC}\n"
