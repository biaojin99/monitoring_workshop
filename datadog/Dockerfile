FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install gunicorn for production-ready WSGI server
RUN pip install gunicorn

# Copy application source code
COPY src/ .

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app
USER app

# Expose port
EXPOSE 3001

# Set environment variables for Datadog
ENV DD_AGENT_HOST=datadog
ENV DD_TRACE_AGENT_PORT=8126
ENV DD_ENV=development
ENV DD_SERVICE=flask-webapp
ENV DD_VERSION=1.0.0

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Run the application with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:3001", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "flask_app:app"] 