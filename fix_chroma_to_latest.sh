#!/usr/bin/env bash
################################################################################
# fix_chroma_to_latest.sh
#
# Purpose:
#   Patches your docker-compose.yml to set Chroma image to "chromadb/chroma:latest".
#   In case the pinned version (e.g. 0.3.25 or 0.3.26) isn't found on Docker Hub,
#   "latest" is more likely to exist. If "latest" also doesn't work, check:
#     https://hub.docker.com/r/chromadb/chroma/tags
#
# Steps:
#   1) Backup docker-compose.yml
#   2) sed-replace "chromadb/chroma:xyz" with "chromadb/chroma:latest"
#   3) Print instructions to rebuild & run.
################################################################################

set -e

COMPOSE_FILE="docker-compose.yml"
TIMESTAMP=$(date +%s)
BACKUP_FILE="docker-compose.yml.bak_${TIMESTAMP}"
CHROMA_TAG="latest"  # You can swap "latest" for a known-good version from Docker Hub.

echo "=== [Step 1] Checking if '$COMPOSE_FILE' exists..."
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[ERROR] '$COMPOSE_FILE' not found in current directory. Aborting."
  exit 1
fi

echo "=== [Step 2] Backing up '$COMPOSE_FILE' to '$BACKUP_FILE'..."
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo "[INFO] Backup created: $BACKUP_FILE"

echo "=== [Step 3] Replacing 'chromadb/chroma:XXX' with 'chromadb/chroma:$CHROMA_TAG'..."
# We'll do a simple sed expression looking for lines with "chromadb/chroma:" followed by digits.
# This also catches older lines if it was "0.3.xx".
sed -i -E "s|(chromadb/chroma):[0-9]+\.[0-9]+\.[0-9]+|\1:${CHROMA_TAG}|g" "$COMPOSE_FILE"

echo "=== [Step 4] Done patching. Confirm changes in '$COMPOSE_FILE'."

cat <<EOT

-----------------------------------------------------------------------------------
NEXT STEPS:
  1) Inspect your updated '$COMPOSE_FILE' to verify the Chroma line, e.g.:
       chroma_service:
         image: chromadb/chroma:${CHROMA_TAG}
  2) Rebuild the Chroma service with no cache:
       docker compose build --no-cache chroma_service
  3) Then bring it up:
       docker compose up -d chroma_service
  4) If you still get "manifest not found," pick a valid tag from Docker Hub:
       https://hub.docker.com/r/chromadb/chroma/tags
     Then re-run this script with that tag in CHROMA_TAG variable.
-----------------------------------------------------------------------------------

[DONE] fix_chroma_to_latest.sh completed successfully.
EOT
