# syntax=docker/dockerfile:1
FROM rust:1.84 as builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
COPY src ./src
RUN cargo build --release

FROM debian:stable-slim
WORKDIR /app
COPY --from=builder /app/target/release/rust_service /app/rust_service
EXPOSE 3000
CMD ["/app/rust_service"]
