FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install build dependencies needed for thriftpy compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first to leverage layer caching
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and set ownership
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port if the processor serves metrics or API (optional)
# EXPOSE 8000

# Start the processor
CMD ["python", "main.py"]