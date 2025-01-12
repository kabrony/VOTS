# syntax=docker/dockerfile:1

# Use a lightweight official Python base
FROM python:3.11-slim-buster

# Avoid buffering Python output (helpful for logs)
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy requirements first, then install (leveraging Docker layer caching)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the code
COPY . /app

# (Optional) If you want a non-root user (best practice for production):
# RUN useradd --create-home appuser
# USER appuser

# Expose ports for Gradio and FastAPI
EXPOSE 8500 9000

# Launch the agent
CMD ["python", "agent.py"]

