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
# Step 1: Get list of all user IDs
API_URL="https://api.ionos.com/cloudapi/v6/um/users"

# Get all users (basic info only)
USERS_RESPONSE=$(curl -s -H "Authorization: Bearer $IONOS_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_URL" || echo '{"items": []}')

# Check if API call was successful
if echo "$USERS_RESPONSE" | jq -e '.items' >/dev/null 2>&1; then
    # Step 2: For each user ID, get detailed info and check email
    USER_IDS=$(echo "$USERS_RESPONSE" | jq -r '.items[].id' 2>/dev/null)
    
    for user_id in $USER_IDS; do
        # Get detailed user information
        USER_DETAILS=$(curl -s -H "Authorization: Bearer $IONOS_TOKEN" \
            -H "Content-Type: application/json" \
            "$API_URL/$user_id" 2>/dev/null || echo '{}')
        
        # Extract email from user details (try multiple possible locations)
        USER_EMAIL=$(echo "$USER_DETAILS" | jq -r '.properties.email // .email // ""' 2>/dev/null || echo "")
        
        # Check if this user's email matches what we're looking for
        if [ "$USER_EMAIL" = "$EMAIL" ]; then
            echo "{\"exists\": \"true\", \"user_id\": \"$user_id\", \"error\": \"\"}"
            exit 0
        fi
    done
    
    # If we get here, user doesn't exist
    echo "{\"exists\": \"false\", \"user_id\": \"\", \"error\": \"\"}"
else
    # API call failed
    echo "{\"exists\": \"false\", \"user_id\": \"\", \"error\": \"Failed to fetch users from IONOS API\"}"
fi