#!/usr/bin/env bash
set -euo pipefail

BASH_FUNCTIONS_REF="main"
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/${BASH_FUNCTIONS_REF}/common-functions.sh"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/docker-compose.yml"
CADDYFILE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/Caddyfile"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/oszuidwest/zwtv-owncast/main/.env.example"

FUNCTIONS_LIB_PATH=$(mktemp)
ENV_EXAMPLE_TMP=$(mktemp)
INSTALL_DIR="/opt/owncast"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
CADDY_FILE="${INSTALL_DIR}/Caddyfile"
ENV_FILE="${INSTALL_DIR}/.env"

trap 'rm -f "$FUNCTIONS_LIB_PATH" "$ENV_EXAMPLE_TMP"' EXIT

clear || true

if ! command -v curl >/dev/null 2>&1; then
  echo "*** curl is required to download the functions library. ***"
  exit 1
fi

if ! curl -fsSL -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo "*** Failed to download functions library. Please check your network connection. ***"
  exit 1
fi

# shellcheck source=/dev/null
source "$FUNCTIONS_LIB_PATH"

set_colors
assert_user_privileged "root"
assert_os_linux
assert_os_64bit
assert_tool "curl" "docker"

CONTAINER_NAMES=("owncast" "caddy")

containers_running() {
  local name
  for name in "${CONTAINER_NAMES[@]}"; do
    if docker ps --filter "name=^${name}$" --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      return 0
    fi
  done
  return 1
}

containers_exist() {
  local name
  for name in "${CONTAINER_NAMES[@]}"; do
    if docker ps -a --filter "name=^${name}$" --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      return 0
    fi
  done
  return 1
}

stop_existing_stack() {
  if [ -f "${COMPOSE_FILE}" ]; then
    (cd "${INSTALL_DIR}" && docker compose down --timeout 30 --remove-orphans) || true
  fi

  local name
  for name in "${CONTAINER_NAMES[@]}"; do
    if docker ps -a --filter "name=^${name}$" --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      docker rm -f "$name" >/dev/null 2>&1 || true
    fi
  done
}

verify_containers_running() {
  sleep 3
  local failed=0
  local name status
  for name in "${CONTAINER_NAMES[@]}"; do
    status="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo missing)"
    if [ "$status" = "running" ]; then
      echo -e "${GREEN}✓ ${name} is ${status}${NC}"
    else
      echo -e "${RED}✗ ${name} is ${status}${NC}"
      failed=1
    fi
  done
  return "$failed"
}

cat << "EOF"
 ______   _ ___ ______        _______ ____ _____   _______     __
|__  / | | |_ _|  _ \ \      / / ____/ ___|_   _| |_   _\ \   / /
  / /| | | || || | | \ \ /\ / /|  _| \___ \ | |     | |  \ \ / /
 / /_| |_| || || |_| |\ V  V / | |___ ___) || |     | |   \ V /
/____|\___/|___|____/  \_/\_/  |_____|____/ |_|     |_|    \_/
EOF

echo -e "${GREEN}⎎ Dockerized Owncast for ZuidWest TV${NC}\n\n"

# Detect existing installation
EXISTING_INSTALL="n"
if [ -f "${ENV_FILE}" ] || [ -f "${COMPOSE_FILE}" ] || containers_exist; then
  EXISTING_INSTALL="y"
  echo -e "${YELLOW}Existing installation detected.${NC}\n"
fi

if containers_running; then
  echo -e "${YELLOW}Owncast is currently running. Continuing will stop the stream.${NC}"
  prompt_user "CONTINUE_INSTALL" "y" "Continue with installation? (y/n)" "y/n"
  if [ "$CONTINUE_INSTALL" != "y" ]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
  fi
  echo ""
fi

prompt_user "DO_UPDATES" "y" "Perform OS updates? (y/n)" "y/n"

# Handle configuration based on existing installation
if [ "$EXISTING_INSTALL" == "y" ] && [ -f "${ENV_FILE}" ]; then
  prompt_user "KEEP_CONFIG" "y" "Keep existing configuration? (y/n)" "y/n"
else
  KEEP_CONFIG="n"
fi

if [ "$KEEP_CONFIG" == "n" ]; then
  prompt_user "STREAM_KEY" "hackme123" "Owncast stream key" "str"
  prompt_user "ADMIN_PASSWORD" "admin123" "Owncast admin password" "str"
  prompt_user "ADMIN_IPS" "0.0.0.0/0" "IPs allowed to access Owncast admin (space-separated, 0.0.0.0/0 = allow all)" "str"
  prompt_user "SSL_HOSTNAME" "owncast.local" "Hostname for SSL proxy (e.g. owncast.example.org)" "host"
  prompt_user "STREAM_NAME" "none" "Stream name (optional, leave empty to skip)" "str"
  prompt_user "LOGO_URL" "none" "Logo URL (optional, leave empty to skip)" "str"
  prompt_user "S3_ENDPOINT" "none" "S3 endpoint (optional, leave empty to skip S3)" "str"
  if [ "$S3_ENDPOINT" != "none" ]; then
    prompt_user "S3_ACCESS_KEY" "" "S3 access key" "str"
    prompt_user "S3_SECRET_KEY" "" "S3 secret key" "str"
    prompt_user "S3_BUCKET" "" "S3 bucket name" "str"
    prompt_user "S3_REGION" "auto" "S3 region (default: auto)" "str"
    prompt_user "S3_ACL" "private" "S3 ACL (default: private)" "str"
    prompt_user "S3_PATH_PREFIX" "none" "S3 path prefix (optional)" "str"
    prompt_user "S3_FORCE_PATH_STYLE" "false" "S3 force path style (true/false, default: false)" "str"
    prompt_user "VIDEO_SERVING_ENDPOINT" "" "Video serving endpoint (optional)" "str"
  else
    S3_ENDPOINT=""
    S3_ACCESS_KEY=""
    S3_SECRET_KEY=""
    S3_BUCKET=""
    S3_REGION="auto"
    S3_ACL="private"
    S3_PATH_PREFIX=""
    S3_FORCE_PATH_STYLE="false"
    VIDEO_SERVING_ENDPOINT=""
  fi

  # Convert 'none' to empty strings for optional fields
  if [ "$STREAM_NAME" = "none" ]; then STREAM_NAME=""; fi
  if [ "$LOGO_URL" = "none" ]; then LOGO_URL=""; fi
  if [ "$S3_PATH_PREFIX" = "none" ]; then S3_PATH_PREFIX=""; fi
fi

# Configure host time settings
set_timezone Europe/Amsterdam
set_time_sync

# Configure journald storage limits
set_journald_limits

if [ "$DO_UPDATES" == "y" ]; then
  apt_update --silent
fi

echo -e "${BLUE}►► Creating installation directory: ${INSTALL_DIR}${NC}"
mkdir -p "${INSTALL_DIR}"

echo -e "${BLUE}►► Downloading docker-compose.yml${NC}"
if ! file_download "${DOCKER_COMPOSE_URL}" "${COMPOSE_FILE}" "docker-compose.yml" --backup; then
  exit 1
fi

echo -e "${BLUE}►► Downloading Caddyfile${NC}"
if ! file_download "${CADDYFILE_URL}" "${CADDY_FILE}" "Caddyfile" --backup; then
  exit 1
fi

if [ "$KEEP_CONFIG" == "y" ]; then
  echo -e "${BLUE}►► Checking for new configuration variables${NC}"
  if curl -fsSL -o "${ENV_EXAMPLE_TMP}" "${ENV_EXAMPLE_URL}"; then
    if ! file_backup "${ENV_FILE}"; then
      exit 1
    fi
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
  echo -e "${BLUE}►► Downloading .env.example and renaming it to .env${NC}"
  if ! file_download "${ENV_EXAMPLE_URL}" "${ENV_FILE}" ".env.example" --backup; then
    exit 1
  fi

  echo -e "${BLUE}►► Filling in the .env file with provided values${NC}"
  sed -i "s|ADMIN_PASSWORD=.*|ADMIN_PASSWORD=\"${ADMIN_PASSWORD}\"|g" "${ENV_FILE}"
  sed -i "s|ADMIN_IPS=.*|ADMIN_IPS=\"${ADMIN_IPS}\"|g" "${ENV_FILE}"
  sed -i "s|STREAM_KEY=.*|STREAM_KEY=\"${STREAM_KEY}\"|g" "${ENV_FILE}"
  sed -i "s|SSL_HOSTNAME=.*|SSL_HOSTNAME=\"${SSL_HOSTNAME}\"|g" "${ENV_FILE}"
  sed -i "s|STREAM_NAME=.*|STREAM_NAME=\"${STREAM_NAME}\"|g" "${ENV_FILE}"
  sed -i "s|LOGO_URL=.*|LOGO_URL=\"${LOGO_URL}\"|g" "${ENV_FILE}"
  sed -i "s|S3_ENDPOINT=.*|S3_ENDPOINT=\"${S3_ENDPOINT}\"|g" "${ENV_FILE}"
  sed -i "s|S3_ACCESS_KEY=.*|S3_ACCESS_KEY=\"${S3_ACCESS_KEY}\"|g" "${ENV_FILE}"
  sed -i "s|S3_SECRET_KEY=.*|S3_SECRET_KEY=\"${S3_SECRET_KEY}\"|g" "${ENV_FILE}"
  sed -i "s|S3_BUCKET=.*|S3_BUCKET=\"${S3_BUCKET}\"|g" "${ENV_FILE}"
  sed -i "s|S3_REGION=.*|S3_REGION=\"${S3_REGION}\"|g" "${ENV_FILE}"
  sed -i "s|S3_ACL=.*|S3_ACL=\"${S3_ACL}\"|g" "${ENV_FILE}"
  sed -i "s|S3_PATH_PREFIX=.*|S3_PATH_PREFIX=\"${S3_PATH_PREFIX}\"|g" "${ENV_FILE}"
  sed -i "s|S3_FORCE_PATH_STYLE=.*|S3_FORCE_PATH_STYLE=\"${S3_FORCE_PATH_STYLE}\"|g" "${ENV_FILE}"
  sed -i "s|VIDEO_SERVING_ENDPOINT=.*|VIDEO_SERVING_ENDPOINT=\"${VIDEO_SERVING_ENDPOINT}\"|g" "${ENV_FILE}"
fi

if [ -n "${STREAM_VARIANTS_JSON:-}" ]; then
  sed -i '/^STREAM_VARIANTS_JSON=/d' "${ENV_FILE}"
  echo "STREAM_VARIANTS_JSON='${STREAM_VARIANTS_JSON}'" >> "${ENV_FILE}"
fi

# Restrict permissions on .env file (contains credentials)
chmod 600 "${ENV_FILE}"

echo -e "\n\n${GREEN}✓ Installation set up at ${INSTALL_DIR}${NC}"
if [ "$KEEP_CONFIG" == "y" ]; then
  echo -e "${YELLOW}Existing configuration has been preserved.${NC}"
else
  echo -e "${YELLOW}The .env file has been populated with the values you provided.${NC}"
fi

prompt_user "START_OWNCAST" "y" "Start Owncast and Caddy now? (y/n)" "y/n"
if [ "$START_OWNCAST" == "y" ]; then
  cd "${INSTALL_DIR}" || exit

  echo -e "${BLUE}►► Validating Docker Compose configuration${NC}"
  docker compose config -q

  if [ "$EXISTING_INSTALL" == "y" ] || containers_exist; then
    echo -e "${BLUE}►► Stopping existing containers${NC}"
    stop_existing_stack
  fi

  echo -e "${BLUE}►► Pulling latest images${NC}"
  docker compose pull

  echo -e "${BLUE}►► Starting containers${NC}"
  docker compose up -d

  echo -e "${BLUE}►► Checking container runtime state${NC}"
  if ! verify_containers_running; then
    echo -e "${RED}*** Some containers are not running. Check 'docker compose logs'. ***${NC}"
    docker compose ps
    exit 1
  fi
  echo -e "${GREEN}✓ All containers are running${NC}"
  docker compose ps

  prompt_user "RUN_POSTINSTALL" "y" "Run the postinstall script? (y/n)" "y/n"

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
