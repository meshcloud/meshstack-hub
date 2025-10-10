#!/bin/bash
# Test script for user existence checking
# Usage: ./test_user_check.sh

echo "Testing IONOS user existence checking..."

# Test cases
TEST_EMAILS=("fnowarre@meshcloud.io" "nonexistent@example.com")

for email in "${TEST_EMAILS[@]}"; do
    echo ""
    echo "Testing email: $email"
    result=$(./check_user_exists.sh "$email")
    echo "Result: $result"

    # Parse result
    exists=$(echo "$result" | jq -r '.exists')
    user_id=$(echo "$result" | jq -r '.user_id')
    error=$(echo "$result" | jq -r '.error')

    if [ "$error" != "" ] && [ "$error" != "null" ]; then
        echo "❌ Error: $error"
    elif [ "$exists" == "true" ]; then
        echo "✅ User exists with ID: $user_id"
    else
        echo "ℹ️  User does not exist - will be created"
    fi
done

echo ""
echo "Test completed!"