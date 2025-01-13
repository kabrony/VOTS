#!/usr/bin/env bash
################################################################################
# fix_nextjs_dashboard.sh
#
# Purpose:
#   1) Creates/overwrites nextjs_dashboard/package.json with a minimal Next.js config
#      ensuring "build" script is present.
#   2) Overwrites nextjs_dashboard/Dockerfile so it can build & run "npm run build".
#
# Usage:
#   ./fix_nextjs_dashboard.sh
#   Then "docker compose build --no-cache nextjs_dashboard && docker compose up -d nextjs_dashboard"
################################################################################

set -e

if [ ! -d "nextjs_dashboard" ]; then
  echo "[ERROR] 'nextjs_dashboard' folder not found in current directory."
  echo "Make sure you're in ~/qmcs/VOTS or adjust paths accordingly."
  exit 1
fi

echo "[INFO] Overwriting nextjs_dashboard/package.json with minimal Next.js config..."

cat << 'EOF' > nextjs_dashboard/package.json
{
  "name": "vots_dashboard",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "13.4.12",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
EOF

echo "[INFO] Creating minimal nextjs_dashboard Dockerfile..."

cat << 'EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1

FROM node:18-alpine AS builder
WORKDIR /app

# Copy package.json only (so we can do a partial npm install first)
COPY package.json ./

# If you do have a lock file, optionally copy it:
# COPY package-lock.json ./

RUN npm install

# Copy the rest of the source
COPY . .

# Run build
RUN npm run build

# -- Final stage: production runtime --
FROM node:18-alpine
WORKDIR /app

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./package.json

# If you do have a lock file, copy it:
# COPY --from=builder /app/package-lock.json ./package-lock.json

COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

echo "[INFO] Done overwriting nextjs_dashboard Dockerfile and package.json."
echo "------------------------------------------------------------"
echo "Now run:"
echo "  docker compose build --no-cache nextjs_dashboard"
echo "  docker compose up -d nextjs_dashboard"
echo "------------------------------------------------------------"
