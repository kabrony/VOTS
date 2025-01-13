#!/usr/bin/env bash
################################################################################
# VOTS_OneStop_Setup.sh
# 
# A single script to unify all microservices (Python agent + Chroma + Next.js +
# local Mongo + optional C & Go) in Docker Compose, with pinned Python dependencies
# that include the latest openai package, google-genai, chromadb, langchain, etc.
#
# WARNING: This will overwrite several files (docker-compose.yml, Dockerfiles,
#          python_agent/requirements.txt, possibly agent.py).
#          Make sure you have backups or commit your code first.
################################################################################

set -e

# 1) Check we are in the correct folder
if [ ! -f "docker-compose.yml" ]; then
  echo "[ERROR] You must run this script inside the ~/qmcs/VOTS/ folder containing 'docker-compose.yml'!"
  exit 1
fi

echo "=== [Step 1] Overwriting python_agent/requirements.txt with pinned versions..."
cat << 'EOF' > python_agent/requirements.txt
# ------------- Python Agent Requirements (Pinned) -------------
# We attempt to unify the conflicting websockets usage between google-genai 0.2.1
# and Gradio 4.53.0 by forcibly using websockets ~13.x.
# If you still see conflict, you may need to tweak versions.

fastapi==0.108.0
uvicorn==0.23.2
requests==2.31.0
python-dotenv==1.0.0

# Latest openai (as of 2025-01)
openai==0.30.0

# Google GenAI for hypothetical Gemini 2.0 usage
google-genai==0.2.1

# Chroma, pinned at 0.4.13
chromadb==0.4.13

# Gradio pinned at 4.53.0
# (One of the more recent versions that hopefully won't fully break websockets)
gradio==4.53.0

# LangChain pinned for consistent usage
langchain==0.0.320

# Pydantic pinned for consistency with above packages
pydantic==2.3.0

# Tiktoken for token counting in LLM usage
tiktoken==0.6.0

# Additional forced pins to help unify websockets:
websockets==13.4.2
EOF
echo "[INFO] python_agent/requirements.txt updated."

echo "=== [Step 2] Overwriting python_agent/Dockerfile..."
cat << 'EOF' > python_agent/Dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim-buster

# Install system-level packages if needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# We'll copy in requirements and do the pip install
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Finally copy the agent code
COPY . /app

EXPOSE 9000 8500
CMD ["python", "agent.py"]
EOF
echo "[INFO] python_agent/Dockerfile updated."

# 3) Optionally unify agent.py calls to openai or google-genai
#    We'll just do a quick check; if user wants to keep existing agent, skip or do minimal.
#    We'll do minimal for demonstration:
if [ -f "python_agent/agent.py" ]; then
  echo "=== [Step 3] Optionally adjusting python_agent/agent.py for openai & google-genai usage..."
  # We'll do a naive sed to mention gemini usage.
  # This is just an example; you might need a more thorough edit.
  sed -i 's/\[Gemini placeholder\]/[Google GenAI - real call or placeholder]/g' python_agent/agent.py || true
  sed -i 's/openai_inference(prompt: str)/openai_inference(prompt: str) -> str/g' python_agent/agent.py || true
  echo "[INFO] Minimal patch done to agent.py for demonstration."
else
  echo "[WARN] python_agent/agent.py not found; skipping agent patch..."
fi

# 4) Overwrite docker-compose.yml
echo "=== [Step 4] Overwriting docker-compose.yml with multi-service config..."
cat << 'EOF' > docker-compose.yml
###############################################################################
# Docker Compose (Compose v2+)
# VOTS Multi-Service: 
#   - Python agent (with fastapi + openai + google-genai + chromadb + gradio)
#   - C microservice (optional)
#   - Go microservice (optional)
#   - Next.js Dashboard
#   - Chroma container (image: chromadb/chroma:latest)
#   - local Mongo container (optional)
#
# Keep in mind your .env should contain:
#   OPENAI_API_KEY, GEMINI_API_KEY, MONGO_URI, etc.
# If using DigitalOcean Mongo, just comment out `vots_mongo`.
###############################################################################
services:

  ######################################################################
  # 1) Python Agent
  ######################################################################
  python_agent:
    build:
      context: ./python_agent
      dockerfile: Dockerfile
    container_name: python_agent
    env_file: .env
    networks:
      - vots_network
    ports:
      - "9000:9000"    # FastAPI port
      - "8500:8500"    # Gradio or second UI port
    depends_on:
      - c_service
      - go_service
      - chroma_service
      - vots_mongo

  ######################################################################
  # 2) C Microservice
  ######################################################################
  c_service:
    build:
      context: ./c_service
      dockerfile: Dockerfile
    container_name: c_service
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${C_PORT:-5000}:5000"

  ######################################################################
  # 3) Go Microservice
  ######################################################################
  go_service:
    build:
      context: ./go_service
      dockerfile: Dockerfile
    container_name: go_service
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${GO_PORT:-4000}:4000"

  ######################################################################
  # 4) Next.js Dashboard
  ######################################################################
  nextjs_dashboard:
    build:
      context: ./nextjs_dashboard
      dockerfile: Dockerfile
    container_name: nextjs_dashboard
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${NEXTJS_PORT:-3001}:3000"
    depends_on:
      python_agent:
        condition: service_started

  ######################################################################
  # (Optional) 5) Chroma container
  ######################################################################
  chroma_service:
    image: chromadb/chroma:latest
    container_name: chroma_service
    networks:
      - vots_network
    environment:
      CHROMA_DB_IMPL: "duckdb+parquet"
      CHROMA_PERSIST_DIRECTORY: "/data"
    volumes:
      - chroma_data:/data
    ports:
      - "8000:8000"

  ######################################################################
  # (Optional) 6) local Mongo container
  ######################################################################
  vots_mongo:
    image: mongo:6
    container_name: vots_mongo
    networks:
      - vots_network
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: mysecret
    ports:
      - "27017:27017"

networks:
  vots_network:
    name: vots_network
    driver: bridge

volumes:
  chroma_data:
    driver: local
  # If you want a volume for local Mongo data:
  # mongo_data:
  #   driver: local
EOF
echo "[INFO] docker-compose.yml overwritten with the new config."

# 5) Overwrite Next.js Dockerfile as a minimal example:
if [ -d "nextjs_dashboard" ]; then
  echo "=== [Step 5] Overwriting nextjs_dashboard/Dockerfile with minimal Next.js build..."
  cat << 'EON' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine as builder
WORKDIR /app

# If you have package-lock.json, uncomment the COPY line
COPY package.json .
# COPY package-lock.json . 
RUN npm install

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./package.json
# If you have a public/ folder, uncomment:
# COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["npm", "run", "start"]
EON
  echo "[INFO] nextjs_dashboard/Dockerfile overwritten."
fi

# 6) Overwrite minimal Dockerfile for c_service (if not existing)
if [ -d "c_service" ]; then
  echo "=== [Step 6] Overwriting c_service/Dockerfile with minimal example..."
  cat << 'EOC' > c_service/Dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:22.04 as builder
RUN apt-get update && apt-get install -y build-essential libmicrohttpd-dev
WORKDIR /app
COPY main.c ./
RUN gcc main.c -o c_service -lmicrohttpd

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libmicrohttpd-dev
WORKDIR /app
COPY --from=builder /app/c_service /app/c_service
EXPOSE 5000
CMD ["/app/c_service"]
EOC
  echo "[INFO] c_service/Dockerfile overwritten."
fi

# 7) Overwrite minimal Dockerfile for go_service (if not existing)
if [ -d "go_service" ]; then
  echo "=== [Step 7] Overwriting go_service/Dockerfile with minimal example..."
  cat << 'EOG' > go_service/Dockerfile
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
EOG
  echo "[INFO] go_service/Dockerfile overwritten."
fi

echo "=== [Step 8] All overwrites done. Next steps: ==="
echo "1) Inspect the newly created/overwritten files to ensure correctness."
echo "2) Run:   docker compose build --no-cache"
echo "          docker compose up -d"
echo "3) Check logs if any conflict remains."
echo "4) Done!"

exit 0
