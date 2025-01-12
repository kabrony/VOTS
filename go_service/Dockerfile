# syntax=docker/dockerfile:1

# 1) Use a Go build image
FROM golang:1.21 AS builder
WORKDIR /app

# 2) Copy Go files (including go.mod + go.sum)
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# 3) Build a statically linked binary (no glibc required):
RUN CGO_ENABLED=0 go build -ldflags='-s -w' -o /go_service main.go

# 4) Final minimal stage: Distroless or scratch
# Option A: Distroless (static)
FROM gcr.io/distroless/static
COPY --from=builder /go_service /go_service
EXPOSE 4000
CMD ["/go_service"]
