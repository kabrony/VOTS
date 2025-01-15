#!/usr/bin/env bash

echo "Removing all Docker images (this is destructive!)"

# 1) List all images by ID
ALL_IMAGES=$(docker images -q)

# 2) If there's anything to remove, remove them
if [ -n "$ALL_IMAGES" ]; then
  docker rmi -f $ALL_IMAGES
  echo "All Docker images have been forcibly removed."
else
  echo "No Docker images found."
fi
