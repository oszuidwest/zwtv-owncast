#!/usr/bin/env bash

# Files to download
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/v2/common-functions.sh"
FUNCTIONS_LIB_PATH=$(mktemp)

# Clean up temporary file on exit
trap 'rm -f "$FUNCTIONS_LIB_PATH"' EXIT

# Constants
HEALTH_CHECK_TIMEOUT=60
MAX_RETRIES=3
RETRY_DELAY=2

# Determine .env file location (supports both Docker container and direct execution)
if [ -f "/.env" ]; then
    ENV_FILE="/.env"
elif [ -f "/opt/owncast/.env" ]; then
    ENV_FILE="/opt/owncast/.env"
elif [ -f "./.env" ]; then
    ENV_FILE="./.env"
else
    ENV_FILE=""
fi

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

# Check if curl is installed
assert_tool "curl"

# Load data from .env
# shellcheck source=/dev/null
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    echo -e "${BLUE}►► Loading configuration from ${ENV_FILE}${NC}"
    source "$ENV_FILE"
else
    echo -e "${RED}*** Error: .env file not found! ***${NC}"
    echo -e "${YELLOW}Searched in: /.env, /opt/owncast/.env, ./.env${NC}"
    exit 1
fi

# Check for required values
if [ -z "${ADMIN_PASSWORD}" ]; then
  echo -e "${RED}*** Error: ADMIN_PASSWORD not found in .env ***${NC}"
  exit 1
fi

if [ -z "${SSL_HOSTNAME}" ]; then
  echo -e "${RED}*** Error: SSL_HOSTNAME not found in .env ***${NC}"
  exit 1
fi

# Set BASE_URL from SSL_HOSTNAME if not already set (for direct execution on host)
: "${BASE_URL:=https://${SSL_HOSTNAME}}"

# Owncast data
USERNAME="admin"
PASSWORD="${ADMIN_PASSWORD}"

# API URLs
STREAM_API_URL="${BASE_URL}/api/admin/config/video/streamoutputvariants"
NOTIFICATION_API_URL="${BASE_URL}/api/admin/config/notifications/browser"
HIDE_VIEWER_COUNT_API_URL="${BASE_URL}/api/admin/config/hideviewercount"
DISABLE_SEARCH_API_URL="${BASE_URL}/api/admin/config/disablesearchindexing"
DISABLE_CHAT_API_URL="${BASE_URL}/api/admin/config/chat/disable"
REMOVE_SOCIAL_HANDLES_API_URL="${BASE_URL}/api/admin/config/socialhandles"
REMOVE_TAGS_API_URL="${BASE_URL}/api/admin/config/tags"
DISABLE_JOIN_MESSAGES_API_URL="${BASE_URL}/api/admin/config/chat/joinmessagesenabled"
PAGE_CONTENT_API_URL="${BASE_URL}/api/admin/config/pagecontent"
NAME_API_URL="${BASE_URL}/api/admin/config/name"
LOGO_API_URL="${BASE_URL}/api/admin/config/logo"

# JSON Payloads
STREAM_JSON_PAYLOAD=$(cat <<EOF
{
    "value": [
        {
            "name": "Low",
            "videoPassthrough": false,
            "audioPassthrough": true,
            "videoBitrate": 1500,
            "audioBitrate": 0,
            "scaledWidth": 640,
            "scaledHeight": 360,
            "cpuUsageLevel": 2,
            "framerate": 25
        },
        {
            "name": "Mid",
            "videoPassthrough": false,
            "audioPassthrough": true,
            "videoBitrate": 2500,
            "audioBitrate": 0,
            "scaledWidth": 854,
            "scaledHeight": 480,
            "cpuUsageLevel": 2,
            "framerate": 25
        },
        {
            "name": "High",
            "videoPassthrough": false,
            "audioPassthrough": true,
            "videoBitrate": 4000,
            "audioBitrate": 0,
            "scaledWidth": 1280,
            "scaledHeight": 720,
            "cpuUsageLevel": 2,
            "framerate": 25
        },
        {
            "name": "Ultra",
            "videoPassthrough": false,
            "audioPassthrough": true,
            "videoBitrate": 6000,
            "audioBitrate": 0,
            "cpuUsageLevel": 2,
            "framerate": 25
        }
    ]
}
EOF
)

NOTIFICATION_JSON_PAYLOAD=$(cat <<EOF
{
    "value": {
        "enabled": false,
        "goLiveMessage": "I've gone live!"
    }
}
EOF
)

HIDE_VIEWER_COUNT_PAYLOAD='{"value": true}'
DISABLE_SEARCH_PAYLOAD='{"value": true}'
DISABLE_CHAT_PAYLOAD='{"value": true}'
REMOVE_SOCIAL_HANDLES_PAYLOAD='{"value": []}'
REMOVE_TAGS_PAYLOAD='{"value": []}'
DISABLE_JOIN_MESSAGES_PAYLOAD='{"value": false}'
PAGE_CONTENT_PAYLOAD='{"value": ""}'

# Optional configurations for name and logo
if [ -n "${STREAM_NAME}" ]; then
    NAME_PAYLOAD="{\"value\": \"${STREAM_NAME}\"}"
fi

if [ -n "${LOGO_URL}" ]; then
    BASE64_IMAGE=$(curl -s "$LOGO_URL" | base64 -w 0)
    LOGO_PAYLOAD="{\"value\": \"data:image/jpeg;base64,$BASE64_IMAGE\"}"
fi

# Function to wait for Owncast to be ready
wait_for_owncast() {
    echo -e "${BLUE}►► Waiting for Owncast to be ready (timeout: ${HEALTH_CHECK_TIMEOUT}s)...${NC}"
    local elapsed=0
    while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
        if curl -s -f "${BASE_URL}/api/status" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Owncast is ready${NC}"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -e "${YELLOW}  Waiting... (${elapsed}s/${HEALTH_CHECK_TIMEOUT}s)${NC}"
    done
    echo -e "${RED}*** Timeout waiting for Owncast to be ready ***${NC}"
    exit 1
}

# Function to perform POST requests with retry logic
perform_post() {
    local url=$1
    local payload=$2
    local description=$3
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "${BLUE}►► ${description} (attempt ${attempt}/${MAX_RETRIES})${NC}"
        response=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            -u "${USERNAME}:${PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "${payload}" \
            "${url}")

        if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
            echo -e "${GREEN}✓ ${description} completed successfully${NC}"
            return 0
        fi

        echo -e "${YELLOW}  Failed with HTTP ${response}, retrying in ${RETRY_DELAY}s...${NC}"
        attempt=$((attempt + 1))
        sleep $RETRY_DELAY
    done

    echo -e "${RED}*** ${description} failed after ${MAX_RETRIES} attempts (HTTP ${response}) ***${NC}"
    exit 1
}

# Wait for Owncast to be ready before configuring
wait_for_owncast

# Perform POST requests (fail-fast: script exits on first failure)
perform_post "${STREAM_API_URL}" "${STREAM_JSON_PAYLOAD}" "Stream Configuration"
perform_post "${NOTIFICATION_API_URL}" "${NOTIFICATION_JSON_PAYLOAD}" "Notification Configuration"
perform_post "${HIDE_VIEWER_COUNT_API_URL}" "${HIDE_VIEWER_COUNT_PAYLOAD}" "Hide Viewer Count"
perform_post "${DISABLE_SEARCH_API_URL}" "${DISABLE_SEARCH_PAYLOAD}" "Disable Search Indexing"
perform_post "${DISABLE_CHAT_API_URL}" "${DISABLE_CHAT_PAYLOAD}" "Disable Chat"
perform_post "${REMOVE_SOCIAL_HANDLES_API_URL}" "${REMOVE_SOCIAL_HANDLES_PAYLOAD}" "Remove Social Handles"
perform_post "${REMOVE_TAGS_API_URL}" "${REMOVE_TAGS_PAYLOAD}" "Remove Tags"
perform_post "${DISABLE_JOIN_MESSAGES_API_URL}" "${DISABLE_JOIN_MESSAGES_PAYLOAD}" "Disable Join Messages"
perform_post "${PAGE_CONTENT_API_URL}" "${PAGE_CONTENT_PAYLOAD}" "Clear Page Content"

# Optional: Set stream name if configured
if [ -n "${STREAM_NAME}" ]; then
    perform_post "${NAME_API_URL}" "${NAME_PAYLOAD}" "Set Stream Name"
fi

# Optional: Set logo if configured
if [ -n "${LOGO_URL}" ]; then
    perform_post "${LOGO_API_URL}" "${LOGO_PAYLOAD}" "Set Logo"
fi
