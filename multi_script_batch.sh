# -------------------------------------------------------------------------
# cat test_dashboard.sh
# -------------------------------------------------------------------------
#!/usr/bin/env bash
# Purpose: Rebuild & test your Next.js dashboard container in VOTS.
# Usage:   ./test_dashboard.sh

set -e

echo "[INFO] Rebuilding nextjs_dashboard container..."
docker compose build --no-cache nextjs_dashboard

echo "[INFO] Starting nextjs_dashboard container..."
docker compose up -d nextjs_dashboard

echo "[INFO] Checking logs (Ctrl+C to quit)..."
docker compose logs -f nextjs_dashboard


# -------------------------------------------------------------------------
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

# Create minimal Dockerfile
cat << 'EOF' > "./$SERVICE_NAME/Dockerfile"
# syntax=docker/dockerfile:1
FROM rust:1.73-slim-bullseye as builder
WORKDIR /usr/src/myapp
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
COPY src ./src
RUN cargo build --release
FROM debian:bullseye-slim
WORKDIR /app
COPY --from=builder /usr/src/myapp/target/release/rust_service /app/rust_tool
EXPOSE 3010
CMD ["/app/rust_tool"]
EOF

# Create minimal main.rs
cat << 'EOF' > "./$SERVICE_NAME/src/main.rs"
use actix_web::{get, App, HttpResponse, HttpServer, Responder};

#[get("/health")]
async fn health() -> impl Responder {
    HttpResponse::Ok().body("OK")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("Rust Tool => 0.0.0.0:3010 (Use /health)");
    HttpServer::new(|| {
        App::new()
            .service(health)
            // Add more routes or logic for your "tool"
    })
    .bind(("0.0.0.0", 3010))?
    .run()
    .await
}
EOF

# Create minimal fix_build.sh or the like if needed
echo "[INFO] Done. A new Rust microservice '$SERVICE_NAME' is created!"
echo "[INFO] 1) Add it to docker-compose.yml if desired."
echo "[INFO] 2) Build:   docker compose build --no-cache $SERVICE_NAME"
echo "[INFO] 3) Run:     docker compose up -d $SERVICE_NAME"
echo "[INFO] 4) Access:  http://localhost:3010/health"
