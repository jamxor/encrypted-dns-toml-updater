#!/bin/bash

# Configuration
CONFIG_FILE="/etc/encrypted-dns-server/encrypted-dns.toml"
SERVICE_NAME="dnscrypt-server"

# 1. Fetch current Public IPv6
NEW_IPv6=$(curl -s -6 https://ifconfig.me)

# Safety check: exit if curl failed
if [[ -z "$NEW_IPv6" ]]; then
    echo "Error: Could not fetch public IPv6 address."
    exit 1
fi

# 2. Find the line number that contains the external IPv6 address
# This avoids needing to "know" the old IP beforehand.
LINE_NUM=$(grep -nE "external.*:[0-9a-fA-F:]+" "$CONFIG_FILE" | cut -d: -f1 | head -n 1)

if [[ -z "$LINE_NUM" ]]; then
    echo "Error: Could not find an IPv6 address line in $CONFIG_FILE"
    exit 1
fi

# 3. Extract the actual IP from that line to compare
OLD_IPv6=$(sed -n "${LINE_NUM}p" "$CONFIG_FILE" | grep -oP 'external\s*=\s*"\K[^"]+')

# 4. Compare and Update
if [ "$NEW_IPv6" != "$OLD_IPv6" ]; then
    echo "IPv6 change detected: $OLD_IPv6 -> $NEW_IPv6"

    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    # Replace the content between quotes on that specific line number
    sed -i "${LINE_NUM}s/external = \"[^\"]*\"/external = \"[$NEW_IPv6]:443\"/" "$CONFIG_FILE"

    systemctl restart "$SERVICE_NAME"
    echo "Config updated on line $LINE_NUM and service restarted."
else
    echo "IPv6 address is current ($NEW_IPv6). No action required."
fi
