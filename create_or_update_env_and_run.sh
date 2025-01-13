#!/usr/bin/env bash
###############################################################################
# create_or_update_env_and_run.sh
#
# A script to:
#   1) Ensure certain environment variables are in .env (without overwriting).
#   2) Rebuild & restart Docker services on your droplet.
#
# Usage:
#   chmod +x create_or_update_env_and_run.sh
#   ./create_or_update_env_and_run.sh
#
# Notes:
#   - Adjust the ENV_VARS array as needed for your project.
#   - If a variable is missing, it's appended with a placeholder or default value.
#   - Docker is then rebuilt & started. No existing env lines are removed.
###############################################################################

set -Eeuo pipefail

ENV_FILE=".env"

# 1) Define the environment variables you want to ensure.
#    Each entry is NAME=VALUE (no quotes).
declare -a ENV_VARS=(
  "MONGO_URI=mongodb+srv://doadmin:REPLACE_ME@private-db.example.com/mydb"
  "OPENAI_API_KEY=sk-your-account-key-here"
  "GEMINI_API_KEY=AIza-someGoogleGeminiKey"
)

echo "=== [Step 1/3] Ensuring .env file exists..."
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[INFO] No .env found. Creating a new one."
  touch "$ENV_FILE"
fi

echo "=== [Step 2/3] Checking & appending missing env vars..."
for entry in "${ENV_VARS[@]}"; do
  KEY="${entry%%=*}"     # everything before '='
  VALUE="${entry#*=}"    # everything after '='

  if grep -qE "^${KEY}=" "$ENV_FILE"; then
    echo " - $KEY already exists in $ENV_FILE, skipping..."
  else
    echo " - $KEY not found, adding it."
    echo "$KEY=$VALUE" >> "$ENV_FILE"
  fi
done

echo "=== Content of .env now has or had =>"
grep -E "^(MONGO_URI|OPENAI_API_KEY|GEMINI_API_KEY)" "$ENV_FILE" || true

echo "=== [Step 3/3] Rebuilding Docker containers..."
docker compose down

docker compose build --no-cache
docker compose up -d

echo "[DONE] Docker containers rebuilt & running. Check logs with:"
echo "docker compose logs -f"
