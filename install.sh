#!/usr/bin/env bash

# Files to download
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/v2/common-functions.sh"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/docker-compose.yml"
CADDYFILE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/Caddyfile"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/.env.example"

# Constants
FUNCTIONS_LIB_PATH=$(mktemp)
ENV_EXAMPLE_TMP=$(mktemp)
INSTALL_DIR="/opt/owncast"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
CADDY_FILE="${INSTALL_DIR}/Caddyfile"
ENV_FILE="${INSTALL_DIR}/.env"

# Clean up temporary files on exit
trap 'rm -f "$FUNCTIONS_LIB_PATH" "$ENV_EXAMPLE_TMP"' EXIT

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

# Detect existing installation
EXISTING_INSTALL="n"
if [ -f "${ENV_FILE}" ] || [ -f "${COMPOSE_FILE}" ] || docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE '^(owncast|caddy)$'; then
  EXISTING_INSTALL="y"
  echo -e "${YELLOW}Existing installation detected.${NC}\n"
fi

# Ask for user input
prompt_user "DO_UPDATES" "y" "Perform OS updates? (y/n)" "y/n"

# Handle configuration based on existing installation
KEEP_CONFIG="n"
if [ "$EXISTING_INSTALL" == "y" ] && [ -f "${ENV_FILE}" ]; then
  prompt_user "KEEP_CONFIG" "y" "Keep existing configuration? (y/n)" "y/n"
fi

if [ "$KEEP_CONFIG" == "n" ]; then
  # Fresh install or user wants to reconfigure
  prompt_user "STREAM_KEY" "hackme123" "Owncast stream key" "str"
  prompt_user "ADMIN_PASSWORD" "admin123" "Owncast admin password" "str"
  prompt_user "ADMIN_IPS" "0.0.0.0/0" "IPs allowed to access Owncast admin (space-separated, 0.0.0.0/0 = allow all)" "str"
  prompt_user "SSL_HOSTNAME" "owncast.local" "Hostname for SSL proxy (e.g. owncast.example.org)" "host"
fi

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
echo -e "${BLUE}►► Downloading docker-compose.yml${NC}"
if ! curl -s -o "${COMPOSE_FILE}" "${DOCKER_COMPOSE_URL}"; then
  echo -e "${RED}*** Failed to download docker-compose.yml. Please check your network connection! ***${NC}"
  exit 1
fi

# Download Caddyfile
echo -e "${BLUE}►► Downloading Caddyfile${NC}"
if ! curl -s -o "${CADDY_FILE}" "${CADDYFILE_URL}"; then
  echo -e "${RED}*** Failed to download Caddyfile. Please check your network connection! ***${NC}"
  exit 1
fi

# Handle .env file
if [ "$KEEP_CONFIG" == "y" ]; then
  # Download .env.example to temp location for merging new variables
  echo -e "${BLUE}►► Checking for new configuration variables${NC}"
  if curl -s -o "${ENV_EXAMPLE_TMP}" "${ENV_EXAMPLE_URL}"; then
    # Add any new variables from .env.example that don't exist in current .env
    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      # Extract variable name
      var_name="${line%%=*}"
      # If variable doesn't exist in current .env, add it
      if ! grep -q "^${var_name}=" "${ENV_FILE}"; then
        echo -e "${YELLOW}  Adding new variable: ${var_name}${NC}"
        echo "$line" >> "${ENV_FILE}"
      fi
    done < "${ENV_EXAMPLE_TMP}"
  fi
else
  # Fresh install: download and configure .env
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
fi

# Restrict permissions on .env file (contains credentials)
chmod 600 "${ENV_FILE}"

# Instructions for next steps
echo -e "\n\n${GREEN}✓ Installation set up at ${INSTALL_DIR}${NC}"
if [ "$KEEP_CONFIG" == "y" ]; then
  echo -e "${YELLOW}Existing configuration has been preserved.${NC}"
else
  echo -e "${YELLOW}The .env file has been populated with the values you provided.${NC}"
fi

# Start Owncast and Caddy
prompt_user "START_OWNCAST" "y" "Start Owncast and Caddy now? (y/n)" "y/n"
if [ "$START_OWNCAST" == "y" ]; then
  cd "${INSTALL_DIR}" || exit

  # Stop existing containers if running (handles upgrades)
  if docker compose ps -q 2>/dev/null | grep -q . || docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE '^(owncast|caddy)$'; then
    echo -e "${BLUE}►► Stopping existing containers${NC}"
    if ! docker compose down --timeout 30 2>/dev/null; then
      echo -e "${YELLOW}  Normal shutdown failed, forcing removal${NC}"
      docker compose down --remove-orphans --timeout 10 2>/dev/null || true
      docker rm -f owncast caddy 2>/dev/null || true
    fi
  fi

  # Pull fresh images
  echo -e "${BLUE}►► Pulling latest images${NC}"
  docker compose pull

  # Start containers
  echo -e "${BLUE}►► Starting containers${NC}"
  docker compose up -d

  # Verify containers are running
  echo -e "${BLUE}►► Verifying containers${NC}"
  sleep 3
  if docker compose ps --format '{{.Name}} {{.Status}}' | grep -q "Up"; then
    echo -e "${GREEN}✓ Containers are running${NC}"
    docker compose ps
  else
    echo -e "${RED}*** Warning: Some containers may not be running properly ***${NC}"
    docker compose ps
  fi

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
