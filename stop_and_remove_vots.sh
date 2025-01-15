#!/usr/bin/env bash

echo "Stopping VOTS containers..."
docker stop nextjs_dashboard python_agent c_service go_service vots_mongo

echo "Removing VOTS containers..."
docker rm nextjs_dashboard python_agent c_service go_service vots_mongo

echo "All specified VOTS containers stopped & removed."
