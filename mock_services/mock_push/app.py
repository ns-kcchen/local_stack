"""
Mock Push Service

This service provides a mock implementation of the Configuration Push Service for local development.
It simulates receiving and processing configuration pushes without actual backend operations.

API Endpoints:
- GET  /healthcheck - Health check endpoint
- POST /push - Receive and process configuration push
- GET  /push/status/{push_id} - Check push status
"""

from fastapi import FastAPI, UploadFile, File, HTTPException, Request
from typing import Dict, Optional
import logging
import uvicorn
import json
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI(
    title="Mock Push Service",
    description="Mock Configuration Push Service for local development",
    version="1.0.0"
)

# In-memory storage for push operations
# Format: {push_id: {status, timestamp, file_info}}
push_history: Dict[str, Dict] = {}
push_counter = 0


# ========================= HEALTH CHECK =========================#

@app.get("/healthcheck")
async def healthcheck():
    """
    Health check endpoint for mgmt-service health_checker

    Returns:
        dict: Service health status
    """
    logger.info("Health check requested")
    return {
        "status": "healthy",
        "service": "mock-push",
        "version": "1.0.0",
        "total_pushes": len(push_history)
    }


# ========================= PUSH OPERATIONS =========================#

@app.post("/push")
async def push_configuration(
    file: UploadFile = File(...),
    tenant_id: Optional[str] = None
):
    """
    Receive and process a configuration push

    Args:
        file: Configuration file to push
        tenant_id: Optional tenant identifier

    Returns:
        dict: Push operation result with push_id
    """
    global push_counter
    push_counter += 1
    push_id = f"push-{push_counter:06d}"

    # Read file content
    content = await file.read()

    try:
        # Try to parse as JSON for validation
        json_content = json.loads(content)
        file_type = "json"
        profile_count = len(json_content) if isinstance(json_content, list) else 1
    except json.JSONDecodeError:
        file_type = "unknown"
        profile_count = 0

    logger.info(f"Received push: {push_id} (file: {file.filename}, size: {len(content)} bytes, type: {file_type})")

    # Store push information
    push_history[push_id] = {
        "push_id": push_id,
        "status": "completed",  # Mock always succeeds immediately
        "timestamp": datetime.utcnow().isoformat(),
        "filename": file.filename,
        "file_size": len(content),
        "file_type": file_type,
        "profile_count": profile_count,
        "tenant_id": tenant_id
    }

    return {
        "status": "success",
        "push_id": push_id,
        "message": f"Configuration pushed successfully ({profile_count} profiles)",
        "timestamp": push_history[push_id]["timestamp"]
    }


@app.get("/push/status/{push_id}")
async def get_push_status(push_id: str):
    """
    Check the status of a push operation

    Args:
        push_id: Push operation identifier

    Returns:
        dict: Push status information

    Raises:
        HTTPException: If push_id not found
    """
    logger.info(f"Status check for push: {push_id}")

    if push_id not in push_history:
        logger.warning(f"Push ID not found: {push_id}")
        raise HTTPException(status_code=404, detail=f"Push ID {push_id} not found")

    return push_history[push_id]


@app.get("/push/history")
async def get_push_history(limit: int = 10):
    """
    Get recent push history

    Args:
        limit: Maximum number of records to return

    Returns:
        dict: List of recent push operations
    """
    logger.info(f"Push history requested (limit: {limit})")

    # Get most recent pushes
    recent_pushes = sorted(
        push_history.values(),
        key=lambda x: x["timestamp"],
        reverse=True
    )[:limit]

    return {
        "total_pushes": len(push_history),
        "recent_pushes": recent_pushes
    }


# ========================= ADMIN ENDPOINTS =========================#

@app.delete("/push/clear")
async def clear_push_history():
    """
    Clear all push history (for testing purposes)

    Returns:
        dict: Operation result
    """
    global push_history, push_counter
    cleared_count = len(push_history)

    push_history.clear()
    push_counter = 0

    logger.info(f"Cleared {cleared_count} push records")

    return {
        "status": "success",
        "cleared_records": cleared_count
    }


# ========================= ROOT ENDPOINT =========================#

@app.get("/")
async def root():
    """
    Root endpoint providing service information

    Returns:
        dict: Service information
    """
    return {
        "service": "Mock Push Service",
        "version": "1.0.0",
        "description": "Mock Configuration Push Service for local development",
        "endpoints": {
            "health": "/healthcheck",
            "push": "POST /push",
            "status": "GET /push/status/{push_id}",
            "history": "GET /push/history",
            "clear": "DELETE /push/clear"
        },
        "statistics": {
            "total_pushes": len(push_history),
            "last_push_id": f"push-{push_counter:06d}" if push_counter > 0 else None
        }
    }


# ========================= APPLICATION STARTUP =========================#

if __name__ == "__main__":
    logger.info("Starting Mock Push Service on port 8081...")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8081,
        log_level="info"
    )
