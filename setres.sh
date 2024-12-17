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
API_URL="https://${SSL_HOSTNAME}/api/admin/config/video/streamoutputvariants"

# Configuration to set
JSON_PAYLOAD=$(cat <<EOF
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
	
# POST to Owncast
echo -e "${BLUE}►► Sending POST request to ${API_URL}${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -u "${USERNAME}:${PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}" \
    "${API_URL}")

# Check status
if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
    echo -e "${GREEN}✓ POST request completed successfully (${response}).${NC}"
else
    echo -e "${RED}*** POST request failed. HTTP status code: ${response} ***${NC}"
    exit 1
fi
