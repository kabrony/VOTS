# Next.js Dashboard (vots_dashboard)

This directory contains the Next.js 13+ dashboard for VOTS.

## Docker Usage

1. Build the Docker image:
   docker compose build --no-cache nextjs_dashboard

2. Run container (detached):
   docker compose up -d nextjs_dashboard

3. Check logs:
   docker compose logs -f nextjs_dashboard

4. Access the dashboard (if mapped 3001:3000 in compose):
   http://localhost:3001

## Development

- npm run dev → starts local dev on port 3000
- npm install && npm run dev → test outside Docker

## Dockerfile Overview
- Multi-stage build
- “builder” stage → runs npm install + npm run build
- final stage → minimal production image w/ .next + public + package.json
