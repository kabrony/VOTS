#!/usr/bin/env bash
################################################################################
# update_services.sh
# ------------------------------------------------------------------------------
# 1) Updates `nextjs_dashboard/Dockerfile` so it won't fail on "package-lock.json"
#    if you don't actually have one in your code.
# 2) Updates "chroma_service" image to a valid tag, e.g., "chroma:0.3.22".
#
# Single batch script with cat commands for your "VOTS" structure.
################################################################################

# 1) Fix the Next.js dashboard Dockerfile so we only copy package-lock.json if it exists.
cat << 'EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1

FROM node:18-alpine as builder
WORKDIR /app

# Copy ONLY package.json by default:
COPY package.json ./

# If you DO have a package-lock.json in your repo, uncomment the next line:
# COPY package-lock.json ./

RUN npm install

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

# If you have package-lock.json, also copy:
# COPY --from=builder /app/package-lock.json ./package-lock.json
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

echo "[INFO] Wrote nextjs_dashboard/Dockerfile without referencing package-lock.json by default."

# 2) Patch docker-compose.yml to fix the chroma_service image tag
#    We’ll do a simple sed replacement if we see "0.3.21". Adjust if your file differs.

if [ -f docker-compose.yml ]; then
  # Backup
  cp docker-compose.yml docker-compose.yml.bak_$(date +%s)

  # Attempt to replace '0.3.21' with '0.3.22' in line referencing chromadb/chroma
  sed -i 's|chroma:0.3.21|chroma:0.3.22|g' docker-compose.yml

  echo "[INFO] Patched docker-compose.yml for chromadb/chroma image tag (0.3.21 -> 0.3.22)."
else
  echo "[WARN] No docker-compose.yml found. Skipped Chroma fix."
fi

echo "--------------------------------------------------------------------------------"
echo "All done. Next steps:"
echo "  1) docker compose build --no-cache"
echo "  2) docker compose up -d"
echo "If you DO have a package-lock.json, uncomment lines in nextjs_dashboard/Dockerfile."
echo "--------------------------------------------------------------------------------"

