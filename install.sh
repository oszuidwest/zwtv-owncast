#!/usr/bin/env bash

# Clear the terminal
clear

# Download the functions library
if ! curl -s -o /tmp/functions.sh https://raw.githubusercontent.com/oszuidwest/bash-functions/main/common-functions.sh; then
  echo -e  "*** Failed to download functions library. Please check your network connection! ***"
  exit 1
fi

# Source the functions file
source /tmp/functions.sh

# Set color variables
set_colors

# Check if running as root
check_user_privileges privileged

# Check if this is Linux
is_this_linux

# Set the timezone
set_timezone Europe/Amsterdam

# Hi!
echo -e "${GREEN}⎎ Dockerized Owncast for ZuidWest TV${NC}\n\n"

# Check if docker is installed 
require_tool "docker"

# Ask for user input
ask_user "DO_UPDATES" "n" "Do you want to perform all OS updates? (y/n)" "y/n"
ask_user "STREAM_KEY" "hackme123" "Pick a stream key for Owncast" "str"
ask_user "ADMIN_PASSWORD" "admin123" "Choose an admin password for Owncast" "str"
ask_user "SSL_HOSTNAME" "owncast.local" "Specify a hostname for the proxy (for example: owncast.example.org)" "host"
ask_user "SSL_EMAIL" "root@localhost.local" "Specify an email address for SSL (for example: webmaster@example.org)" "email"

# Run updates if DO_UPDATES is 'y'
if [ "$DO_UPDATES" = "y" ]; then
  update_os
fi

@TODO: more shit

echo -e "${GREEN}Installation checks passed. You can now start streaming.${NC}"
