# syntax=docker/dockerfile:1
FROM golang:1.21 as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /go_service main.go

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /go_service /app/go_service
EXPOSE 4000
CMD ["/app/go_service"]
