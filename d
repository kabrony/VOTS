################################################################################
# Overwrite docker-compose.yml
################################################################################
cat << 'EOF' > docker-compose.yml
###############################################################################
# Docker Compose - VOTS Full Multi-Service (Extended with LocalAI placeholder)
###############################################################################

services:

  ######################################################################
  # 1) Python Agent (synergy + PDF ingestion)
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
      - "${FASTAPI_PORT:-9000}:9000"
      - "${GRADIO_PORT:-8500}:8500"
    restart: unless-stopped
    depends_on:
      - c_service
      - go_service
      - rust_service
      - vots_mongo
      # (Optional) If synergy logic requires localai, uncomment next line:
      # - localai

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
    restart: unless-stopped

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
    restart: unless-stopped

  ######################################################################
  # 4) Rust Microservice
  ######################################################################
  rust_service:
    build:
      context: ./rust_service
      dockerfile: Dockerfile
    container_name: rust_service
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${RUST_PORT:-3500}:3000"
    restart: unless-stopped
    # depends_on removed to avoid cyclical dependency

  ######################################################################
  # 5) Next.js Dashboard (port 3001)
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
    restart: unless-stopped
    depends_on:
      - python_agent
      - rust_service
      # (Optional) If synergy logic requires localai, uncomment next line:
      # - localai

  ######################################################################
  # 6) Mongo container
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

  ######################################################################
  # 7) LocalAI container (Optional)
  #    CPU version shown. Adjust if you have GPU or specialized arch.
  #    If synergy logic doesn't require LocalAI, you may remove this block.
  ######################################################################
  localai:
    image: localai/localai:latest-aio-cpu
    container_name: localai
    env_file: .env
    networks:
      - vots_network
    ports:
      - "8080:8080"
    restart: unless-stopped

###############################################################################
# Shared network & volumes
###############################################################################
networks:
  vots_network:
    driver: bridge

volumes:
  chroma_data:
    driver: local
EOF

echo "[INFO] Overwrote docker-compose.yml."

################################################################################
# Overwrite .env
################################################################################
cat << 'EOF' > .env
###############################################################################
# Docker .env for VOTS + LocalAI synergy expansions
###############################################################################

# Container Ports
RUST_PORT=3500
GO_PORT=4000
C_PORT=5000
GRADIO_PORT=8500
FASTAPI_PORT=9000
NEXTJS_PORT=3001

# =======================================================
# Database Configurations
# =======================================================
MYSQL_DATABASE=rag_flow
MYSQL_USER=ragflowuser
MYSQL_PASSWORD=ragflow123
MYSQL_ROOT_PASSWORD=mysecretpassword

# Redis
REDIS_PASSWORD=myredispass

# =======================================================
# MongoDB (renamed to MONGO_URI for consistency)
# e.g. "mongodb+srv://<username>:<password>@host/dbname"
# =======================================================
MONGO_URI=mongodb+srv://root:mysecret@somehost/vots_db

# =======================================================
# Solana
# =======================================================
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
SOLANA_PRIVATE_KEY=replace-with-your-key

# =======================================================
# LLM / External API Keys
# =======================================================
OPENAI_API_KEY=sk-svcacct-ZNKmfYifQWlnq2SO3RAEp-lsqE4VAS-AaIciknm_TCPTloZlc2DGCkNS9UyyBT3BlbkFJnUSSSvauBWoiwL7zfc9MNj0VPss742ruCgay8Ksaa4fsmWXXS3BCdUkAez1eAA
GEMINI_API_KEY=AIzaSyCoaDruS_LQBvgFFD46jiSINB6aLODC7Xk
DEEPSEEK_API_KEY=sk-2753ea93a4704ebe8ecbd2e0
TAVILY_API_KEY=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
# Example LocalAI environment variable:
LOCALAI_URL=http://localai:8080
LOCALAI_API_KEY=dummy-localai-key

# Additional expansions or placeholders
#EXAMPLE_FEATURE_FLAG=false
#ANY_OTHER_SECRET=...

EOF

echo "[INFO] Overwrote .env."

echo "==============================================================="
echo "[REMINDER] Now run the following to rebuild & start containers:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
echo "==============================================================="
