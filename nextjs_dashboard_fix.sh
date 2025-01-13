#!/usr/bin/env bash
################################################################################
# nextjs_dashboard_fix.sh
#
# If you don't have a package-lock.json, remove it from COPY lines so Docker
# build won't error with "package-lock.json not found".
#
# USAGE:
#   1) cd nextjs_dashboard
#   2) ./nextjs_dashboard_fix.sh
#   3) Inspect Dockerfile you just wrote, then do "docker compose build"
################################################################################

cat << 'EOF' > Dockerfile
# syntax=docker/dockerfile:1

FROM node:18-alpine as builder

WORKDIR /app

# COPY just package.json if you DO NOT have package-lock.json
COPY package.json ./

# If you do have a package-lock.json in your repo, uncomment next line:
# COPY package-lock.json ./

# If you keep package-lock.json, best to do npm ci. Otherwise do npm install.
RUN npm install

# Now copy remaining files
COPY . .

# Build Next.js
RUN npm run build

# === Final Stage ===
FROM node:18-alpine
WORKDIR /app

# Copy only what’s needed to run
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json .
# If needed, also copy package-lock.json from builder if you want to run npm ci
# COPY --from=builder /app/package-lock.json .

EXPOSE 3000

CMD ["npm", "run", "start"]
EOF

echo "--------------------------------------------------------------------------------"
echo "[INFO] Wrote Dockerfile without referencing package-lock.json by default."
echo "[INFO] If you do have a package-lock.json, uncomment lines in Dockerfile."
echo ""
echo "Now you can: docker compose build nextjs_dashboard && docker compose up -d"
echo "--------------------------------------------------------------------------------"
