# cat new_rust_tool.sh
# -------------------------------------------------------------------------
#!/usr/bin/env bash
# Purpose: Create a new Rust microservice skeleton to act as a 'tool'
#          that can be called by the Python Agent.
# Usage:   ./new_rust_tool.sh <SERVICE_NAME> e.g. ./new_rust_tool.sh rust_tool

set -e

SERVICE_NAME="$1"

if [ -z "$SERVICE_NAME" ]; then
  echo "[ERROR] Please specify a new Rust microservice name, e.g. ./new_rust_tool.sh rust_tool"
  exit 1
fi

echo "[INFO] Creating directory structure: $SERVICE_NAME..."
mkdir -p "./$SERVICE_NAME/src"

# Create minimal Cargo.toml
cat << EOF > "./$SERVICE_NAME/Cargo.toml"
[package]
name = "$SERVICE_NAME"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
tokio = { version = "1", features = ["macros"] }
EOF
