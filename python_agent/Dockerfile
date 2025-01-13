# syntax=docker/dockerfile:1
FROM python:3.11-slim-bookworm

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
