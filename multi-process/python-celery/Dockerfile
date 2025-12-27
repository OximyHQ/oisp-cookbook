# Python Celery worker image
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY tasks.py .
COPY app.py .

# Default: run as Celery worker
# Override with docker compose to run app.py
CMD ["celery", "-A", "tasks", "worker", "--loglevel=info", "--concurrency=2"]
