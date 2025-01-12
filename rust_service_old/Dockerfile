# syntax=docker/dockerfile:1
FROM rust:1.72-slim as builder

# 1) Create a new empty directory for the app
WORKDIR /app

# 2) Copy Cargo files first (for caching dependencies)
COPY Cargo.toml Cargo.lock ./

# 3) Pre-download (fetch) dependencies 
#    If you prefer, you can do "cargo build --release || true" to cache as well.
RUN cargo fetch

# 4) Now copy the actual source code
COPY src ./src

# 5) Build a release binary
RUN cargo build --release

# --- Final minimal image ---
FROM debian:stable-slim
WORKDIR /app

# 6) Copy the compiled binary from the builder stage
COPY --from=builder /app/target/release/rust_service .

EXPOSE 3000

# 7) Command to run the service
CMD ["./rust_service"]
