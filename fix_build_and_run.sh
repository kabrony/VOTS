#!/usr/bin/env bash
set -euo pipefail

echo "[STEP 0] Removing old containers/images..."
docker compose down --rmi all -v || true
docker system prune -af || true

echo "[STEP 1] Regenerate Rust lockfile..."
pushd rust_service
mv Cargo.lock Cargo.lock.bak || true
cargo generate-lockfile
popd

echo "[STEP 2] Regenerate Go sum if needed..."
pushd go_service
[ -f go.sum ] || touch go.sum
go mod tidy
popd

echo "[STEP 3] Full Docker Compose Rebuild..."
docker compose build --no-cache

echo "[STEP 4] Docker Compose Up..."
docker compose up -d

echo "[STEP 5] Check logs / health..."
docker compose ps
