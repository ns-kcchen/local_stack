FROM python:3.10-slim

# Create nsadmin user (non-root) for security and consistency with other services
RUN groupadd -r nsadmin && useradd -r -g nsadmin nsadmin

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file (from local_stack/pkg)
COPY aisecurity-profile-api/local_stack/pkg/requirements.txt ./requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the aisecurity-profile-api application, shared commonlib, and host service lib (match production structure)
COPY __init__.py /app/src/__init__.py
COPY commonlib /app/src/commonlib
COPY lib /app/src/lib
COPY aisecurity-profile-api /app/src/aisecurity-profile-api

# Copy entrypoint script
COPY aisecurity-profile-api/local_stack/pkg/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Change ownership of all app files to nsadmin
RUN chown -R nsadmin:nsadmin /app

# Switch to non-root user
USER nsadmin

# Set Python path to enable:
# 1. import lib -> /app/src/aisecurity-profile-api/lib (mgmt-service lib)
# 2. from ns_log import ... -> /app/src/lib/ns_log.py (host-service lib, no __init__.py trigger)
# 3. from src.commonlib import ... -> /app/src/commonlib (via /app in entrypoint.sh or direct)
ENV PYTHONPATH=/app/src/aisecurity-profile-api:/app/src/aisecurity-profile-api/lib:/app/src/aisecurity-profile-api/api:/app/src/lib:/app

# Default database configuration (can be overridden by environment variables)
ENV DB_ADDR="10.136.124.198:27017"
ENV DB_ACCOUNT="cXVlcnlfc2VydmljZQo="
ENV DB_CREDENT="UzNjdXIzVGgzQ2wwdWQK"
ENV DB_NAME="AISecurityProfileDB"

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health/liveness || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Command to run the application (no cd needed, PYTHONPATH handles module resolution)
# --no-access-log: Disable uvicorn access log (cyclic logging not allowed per Logging-Standards.md)
# --log-level warning: Only show warning/error from uvicorn itself
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "warning", "--no-access-log"]