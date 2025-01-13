#!/usr/bin/env bash
################################################################################
# vots_compose_batch.sh
#
#  - Writes out a docker-compose.yml with:
#     * python_agent (with optional Gemini/OpenAI, local or remote Mongo, Chroma)
#     * c_service
#     * go_service
#     * nextjs_dashboard
#     * chroma_service (local container)
#     * vots_mongo (local container) but references .env for MONGO_URI
#
#  - If you already have a remote DigitalOcean Mongo instance, you can EITHER
#    comment out the vots_mongo container below and set MONGO_URI in .env to
#    your DO connection string, or run local container for dev.
#
# USAGE:
#   1) Save as `vots_compose_batch.sh`, `chmod +x vots_compose_batch.sh`.
#   2) Run: `./vots_compose_batch.sh`
#   3) Inspect/modify generated docker-compose.yml. Then:
#      docker compose build --progress=plain
#      docker compose up -d
#      docker compose logs -f python_agent
################################################################################

cat << 'EOF' > docker-compose.yml
###############################################################################
# Docker Compose (Compose v2+)
# VOTS Multi-Service: Python, C, Go, Next.js, Chroma, optional local Mongo
###############################################################################
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
      - "8500:8500"    # e.g., Gradio or any second UI port
    depends_on:
      - c_service
      - go_service
      - chroma_service    # comment out if you don't use containerized Chroma
      - vots_mongo        # comment out if you only use DO remote Mongo

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
    # Optionally add healthcheck if your code has /health route
    # healthcheck:
    #   test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
    #   interval: 15s
    #   timeout: 5s
    #   retries: 3

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
    # healthcheck:
    #   test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
    #   interval: 15s
    #   timeout: 5s
    #   retries: 3

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
    # You can also do condition: service_healthy if python_agent has healthcheck

  ######################################################################
  # (Optional) 5) Chroma container
  ######################################################################
  chroma_service:
    image: chromadb/chroma:0.3.21
    container_name: chroma_service
    networks:
      - vots_network
    environment:
      CHROMA_DB_IMPL: "duckdb+parquet"
      CHROMA_PERSIST_DIRECTORY: "/data"
    volumes:
      - chroma_data:/data
    # By default, it listens on port 8000 internally
    # If you need to expose externally, do this:
    ports:
      - "8000:8000"

  ######################################################################
  # (Optional) 6) local Mongo container
  # If you prefer DigitalOcean remote, comment out & set MONGO_URI in .env
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
    # If you want a volume for data:
    # volumes:
    #   - mongo_data:/data/db

networks:
  vots_network:
    name: vots_network
    driver: bridge

volumes:
  chroma_data:
    driver: local
  # mongo_data:
  #   driver: local
EOF

echo "------------------------------------------------------------------------------"
echo "[INFO] Wrote docker-compose.yml with Python Agent, C/Go microservices, Next.js"
echo "[INFO] Also includes optional Chroma and local Mongo containers."
echo ""
echo "NEXT STEPS:"
echo " 1) Adjust or remove any optional containers you don't want (chroma_service, vots_mongo)."
echo " 2) Ensure your .env has all relevant keys, e.g. OPENAI_API_KEY, GEMINI_API_KEY, MONGO_URI."
echo " 3) 'docker compose build --progress=plain && docker compose up -d'"
echo " 4) Check logs: 'docker compose logs -f python_agent' etc."
echo ""
echo "If you're using remote DigitalOcean Mongo, comment out vots_mongo & set MONGO_URI"
echo "in .env to your DO connection string, e.g.:"
echo "  MONGO_URI=\"mongodb+srv://doadmin:<PASSWORD>@private-db-mongodb-nyc3-xxxx.mongo.ondigitalocean.com/admin?tls=true\""
echo "------------------------------------------------------------------------------"
