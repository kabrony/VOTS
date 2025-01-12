# syntax=docker/dockerfile:1

FROM ubuntu:22.04 AS builder
RUN apt-get update && apt-get install -y build-essential libmicrohttpd-dev

WORKDIR /app

COPY main.c ./
RUN gcc main.c -o c_service -lmicrohttpd

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libmicrohttpd-dev

WORKDIR /app
COPY --from=builder /app/c_service .
EXPOSE 5000

CMD ["./c_service"]
