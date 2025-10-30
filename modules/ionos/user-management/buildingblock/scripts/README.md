# User Management Scripts

This directory contains helper scripts for the IONOS user management module.

## Scripts

### `check_user_exists.sh`
Checks if a user exists in IONOS Cloud by email address.

**Usage:**
```bash
./check_user_exists.sh "user@example.com"
```

**Requirements:**
- `IONOS_TOKEN` environment variable set
- `curl` command available
- `jq` command available

**Output:**
Returns JSON with user existence information:
```json
{
  "exists": "true|false",
  "user_id": "user-id-if-exists",
  "error": "error-message-if-any"
}
```

### Installing jq

**macOS:**
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq
```

**CentOS/RHEL:**
```bash
sudo yum install jq
```

## Environment Variables

- `IONOS_TOKEN` - Your IONOS API token with user management permissions