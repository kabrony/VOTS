# rust_service/Dockerfile
# syntax=docker/dockerfile:1

### ---- 1. BUILDER STAGE ----
FROM rust:1.84 as builder
WORKDIR /app

# Copy your Cargo.* first for caching
COPY Cargo.toml Cargo.lock ./

# Pre-build a dummy to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release || true

# Now copy your real src
COPY src ./src
# Build your final release binary
RUN cargo build --release

### ---- 2. FINAL STAGE ----
FROM debian:stable-slim

# 1) Update and install dependencies (ca-certificates, libssl, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built artifact from builder
COPY --from=builder /app/target/release/rust_service /app/rust_service

# Optional, if you need SSL certs for outbound requests
RUN update-ca-certificates

EXPOSE 3000
CMD ["/app/rust_service"]
