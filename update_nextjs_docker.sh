#!/usr/bin/env bash
set -e

echo "==============================================================================="
echo "Overwriting 'update_nextjs_docker.sh' in current folder..."
echo "Actually, this script is self-contained and won't rewrite itself, only the"
echo "'.dockerignore' and 'Dockerfile' in 'nextjs_dashboard/'."
echo "==============================================================================="

# 1) Check if nextjs_dashboard folder exists
if [ ! -d "nextjs_dashboard" ]; then
  echo "ERROR: 'nextjs_dashboard/' not found. Aborting."
  exit 1
fi

echo "Creating/Overwriting '.dockerignore' in 'nextjs_dashboard/'..."
cat << 'IGNORE_EOF' > nextjs_dashboard/.dockerignore
node_modules
.git
.next
*.log
*.cache
Dockerfile
.dockerignore
IGNORE_EOF

echo "Creating/Overwriting 'Dockerfile' in 'nextjs_dashboard/'..."

cat << 'DOCKERFILE_EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1

######################################################################
# (1) BUILDER STAGE
######################################################################
FROM node:18-alpine AS builder
WORKDIR /app

# Copy lockfiles if present, and install
COPY package*.json ./

# If package-lock.json exists, use npm ci; otherwise npm install
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Now copy everything else
COPY . ./

# Build
RUN npm run build

######################################################################
# (2) PRODUCTION STAGE
######################################################################
FROM node:18-alpine
WORKDIR /app

# Copy build artifacts from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./

# Production install only
RUN if [ -f package-lock.json ]; then npm ci --production; else npm install --production; fi

EXPOSE 3000
CMD ["npm", "run", "start"]
DOCKERFILE_EOF

cat << 'HELP_EOF'
===============================================================================
DONE! Updated:
  - nextjs_dashboard/.dockerignore
  - nextjs_dashboard/Dockerfile

To build the Next.js app via Docker Compose:
  1) cd ~/qmcs/VOTS
  2) docker compose build --no-cache nextjs_dashboard
  3) docker compose up -d nextjs_dashboard

Check logs:
  docker compose logs -f nextjs_dashboard

Then open http://localhost:3001 (assuming NEXTJS_PORT=3001) in your browser.
===============================================================================
HELP_EOF
