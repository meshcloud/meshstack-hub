#!/bin/bash
# Script to check if an IONOS user exists
# Usage: ./check_user_exists.sh <email>

set -e

EMAIL="$1"

if [ -z "$EMAIL" ]; then
    echo '{"exists": "false", "user_id": "", "error": "No email provided"}'
    exit 0
fi

# Check if IONOS_TOKEN is set
if [ -z "$IONOS_TOKEN" ]; then
    echo '{"exists": "false", "user_id": "", "error": "IONOS_TOKEN not set"}'
    exit 0
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo '{"exists": "false", "user_id": "", "error": "jq command not found - please install jq"}'
    exit 0
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo '{"exists": "false", "user_id": "", "error": "curl command not found - please install curl"}'
    exit 0
fi

# Use IONOS API to check if user exists
# API endpoint: https://api.ionos.com/cloudapi/v6/um/users
API_URL="https://api.ionos.com/cloudapi/v6/um/users"

# Make API request to list users and check if email exists
RESPONSE=$(curl -s -H "Authorization: Bearer $IONOS_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_URL" || echo '{"items": []}')

# Parse response to check if user with email exists
USER_EXISTS=$(echo "$RESPONSE" | jq -r ".items[]? | select(.properties.email == \"$EMAIL\") | .id" 2>/dev/null || echo "")

if [ -n "$USER_EXISTS" ] && [ "$USER_EXISTS" != "null" ]; then
    echo "{\"exists\": \"true\", \"user_id\": \"$USER_EXISTS\", \"error\": \"\"}"
else
    echo "{\"exists\": \"false\", \"user_id\": \"\", \"error\": \"\"}"
fi