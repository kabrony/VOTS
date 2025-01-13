#!/usr/bin/env bash
################################################################################
# fix_chroma_version.sh
#
# Purpose: 
#   1) Update your docker-compose.yml to use a valid Chroma image tag,
#      since "chromadb/chroma:0.3.21" or "0.3.22" might not exist anymore.
#   2) Optionally fix "vots_mongo" if there's an invalid image tag or other issues.
#
# Steps:
#   1) Backup docker-compose.yml
#   2) Attempt to replace any "chromadb/chroma:0.3.xx" with "chromadb/chroma:0.3.25"
#      or you can set it to "latest".
#   3) Provide instructions to rebuild & run.
################################################################################

set -e

COMPOSE_FILE="docker-compose.yml"
TIMESTAMP=$(date +%s)
BACKUP_FILE="docker-compose.yml.bak_${TIMESTAMP}"
VALID_CHROMA_TAG="0.3.25"  # or "latest"

echo "=== [Step 1] Checking if '$COMPOSE_FILE' exists..."
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[ERROR] '$COMPOSE_FILE' not found in current directory. Aborting."
  exit 1
fi

echo "=== [Step 2] Backing up your '$COMPOSE_FILE' to '$BACKUP_FILE'..."
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo "[INFO] Backup created: $BACKUP_FILE"

echo "=== [Step 3] Updating references to Chroma 'chromadb/chroma:0.3.xx'..."
# We'll do a simple sed replace for lines with "chromadb/chroma:"
# and swap it with "chromadb/chroma:0.3.25" or your chosen tag.

# This sed pattern looks for "chromadb/chroma:" followed by digits/dots,
# and replaces everything up to the next space with the new tag.
# If you prefer "latest", set $VALID_CHROMA_TAG="latest".
sed -i -E "s|(chromadb/chroma):[0-9]+\.[0-9]+\.[0-9]+|\1:$VALID_CHROMA_TAG|g" "$COMPOSE_FILE"

echo "=== [Step 4] Checking if 'vots_mongo' or 'my_mongo' references are invalid..."
# This step is optional. If you have a line like "image: mongo:6" or something else,
# you can confirm it. We'll just do a quick check for 'image: vots_mongo' lines.

if grep -q "image: vots_mongo" "$COMPOSE_FILE"; then
  echo "[WARN] Found line 'image: vots_mongo'. Make sure that image exists or set a valid 'mongo:6' or 'mongo:latest'."
  echo "No automatic fix done here, but you can manually update if needed."
fi

echo "=== [Step 5] Done patching. Confirm changes in '$COMPOSE_FILE'."

cat <<EOT

-----------------------------------------------------------------------------------
NEXT STEPS:
  1) Inspect your updated '$COMPOSE_FILE' to verify Chroma lines, e.g.:
       chroma_service:
         image: chromadb/chroma:0.3.25
         ...
  2) Rebuild the Chroma service with no cache:
       docker compose build --no-cache chroma_service
  3) Then bring it up:
       docker compose up -d chroma_service
  4) Check logs if still seeing errors:
       docker compose logs -f chroma_service
-----------------------------------------------------------------------------------

[DONE] fix_chroma_version.sh completed successfully.
EOT

