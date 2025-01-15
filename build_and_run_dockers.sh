#!/usr/bin/env bash

echo "Stopping and removing old containers (if any)..."
docker compose down

echo "Building Docker images WITHOUT cache..."
docker compose build --no-cache

echo "Starting containers in detached mode..."
docker compose up -d

echo "If you want to see logs, run: docker compose logs -f"
