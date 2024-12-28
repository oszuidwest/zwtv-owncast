#!/usr/bin/env bash

# Files to download
FUNCTIONS_LIB_URL="https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh"
FUNCTIONS_LIB_PATH="/tmp/functions.sh"

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Remove old functions library and download the latest version
rm -f "$FUNCTIONS_LIB_PATH"
if ! curl -s -o "$FUNCTIONS_LIB_PATH" "$FUNCTIONS_LIB_URL"; then
  echo -e "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
# shellcheck source=/dev/null
source "$FUNCTIONS_LIB_PATH"

# Load data from .env
# shellcheck source=/dev/null
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}*** Error: .env file not found in ${SCRIPT_DIR}! ***${NC}"
    exit 1
fi

# Set color variables
set_colors

# Check if curl is installed
require_tool "curl"

# Check for required values
if [ -z "${ADMIN_PASSWORD}" ]; then
  echo -e "${RED}*** Error: ADMIN_PASSWORD not found in .env ***${NC}"
  exit 1
fi

if [ -z "${SSL_HOSTNAME}" ]; then
  echo -e "${RED}*** Error: SSL_HOSTNAME not found in .env ***${NC}"
  exit 1
fi

# Owncast data
USERNAME="admin"
PASSWORD="${ADMIN_PASSWORD}"

# API URLs
STREAM_API_URL="https://${SSL_HOSTNAME}/api/admin/config/video/streamoutputvariants"
NOTIFICATION_API_URL="https://${SSL_HOSTNAME}/api/admin/config/notifications/browser"
HIDE_VIEWER_COUNT_API_URL="https://${SSL_HOSTNAME}/api/admin/config/hideviewercount"
DISABLE_SEARCH_API_URL="https://${SSL_HOSTNAME}/api/admin/config/disablesearchindexing"
DISABLE_CHAT_API_URL="https://${SSL_HOSTNAME}/api/admin/config/chat/disable"
REMOVE_SOCIAL_HANDLES_API_URL="https://${SSL_HOSTNAME}/api/admin/config/socialhandles"
REMOVE_TAGS_API_URL="https://${SSL_HOSTNAME}/api/admin/config/tags"
DISABLE_JOIN_MESSAGES_API_URL="https://${SSL_HOSTNAME}/api/admin/config/chat/joinmessagesenabled"

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
            "videoBitrate": 3500,
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
            "videoBitrate": 5000,
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

# Function to perform POST requests
perform_post() {
    local url=$1
    local payload=$2
    local description=$3

    echo -e "${BLUE}►► Sending POST request to ${url} (${description})${NC}"
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${url}")

    if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
        echo -e "${GREEN}✓ ${description} POST request completed successfully (${response}).${NC}"
    else
        echo -e "${RED}*** ${description} POST request failed. HTTP status code: ${response} ***${NC}"
    fi
}

# Perform POST requests
perform_post "${STREAM_API_URL}" "${STREAM_JSON_PAYLOAD}" "Stream Configuration"
perform_post "${NOTIFICATION_API_URL}" "${NOTIFICATION_JSON_PAYLOAD}" "Notification Configuration"
perform_post "${HIDE_VIEWER_COUNT_API_URL}" "${HIDE_VIEWER_COUNT_PAYLOAD}" "Hide Viewer Count"
perform_post "${DISABLE_SEARCH_API_URL}" "${DISABLE_SEARCH_PAYLOAD}" "Disable Search Indexing"
perform_post "${DISABLE_CHAT_API_URL}" "${DISABLE_CHAT_PAYLOAD}" "Disable Chat"
perform_post "${REMOVE_SOCIAL_HANDLES_API_URL}" "${REMOVE_SOCIAL_HANDLES_PAYLOAD}" "Remove Social Handles"
perform_post "${REMOVE_TAGS_API_URL}" "${REMOVE_TAGS_PAYLOAD}" "Remove Tags"
perform_post "${DISABLE_JOIN_MESSAGES_API_URL}" "${DISABLE_JOIN_MESSAGES_PAYLOAD}" "Disable Join Messages"