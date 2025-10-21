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

# Copy main application code (build context is /Users/kcc/repo/AISecurityService/src)
COPY . ./src/

# Copy profile API specific code
COPY aisecurity-profile-api/api/ ./api/
COPY aisecurity-profile-api/lib/ ./lib/
COPY aisecurity-profile-api/local_stack/pkg/static/ ./static/

# Copy entrypoint script
COPY aisecurity-profile-api/local_stack/pkg/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Change ownership of all app files to nsadmin
RUN chown -R nsadmin:nsadmin /app

# Switch to non-root user
USER nsadmin

# Set Python path
ENV PYTHONPATH=/app

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

# Command to run the application
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]