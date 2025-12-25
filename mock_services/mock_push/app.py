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
import os
import hashlib

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

# Storage directory for pushed files
STORAGE_DIR = os.getenv("PUSH_STORAGE_DIR", "/tmp/mock_push_storage")
os.makedirs(STORAGE_DIR, exist_ok=True)

# File validation settings
VALIDATE_FILES = os.getenv("VALIDATE_PUSH_FILES", "true").lower() == "true"
DELETE_AFTER_VALIDATION = os.getenv("DELETE_AFTER_VALIDATION", "true").lower() == "true"

logger.info(f"Mock Push Service Configuration:")
logger.info(f"  Storage directory: {STORAGE_DIR}")
logger.info(f"  Validate files: {VALIDATE_FILES}")
logger.info(f"  Delete after validation: {DELETE_AFTER_VALIDATION}")


# ========================= HELPER FUNCTIONS =========================#

def save_and_validate_file(push_id: str, content: bytes, filename: str) -> Dict:
    """
    Save pushed file to storage and validate its content

    Args:
        push_id: Unique push identifier
        content: File content bytes
        filename: Original filename

    Returns:
        dict: Validation result with file info
    """
    result = {
        "saved": False,
        "validated": False,
        "deleted": False,
        "error": None,
        "file_path": None,
        "checksum": None,
        "profile_count": 0
    }

    try:
        # Calculate checksum
        checksum = hashlib.md5(content).hexdigest()
        result["checksum"] = checksum

        # Save file
        file_path = os.path.join(STORAGE_DIR, f"{push_id}_{filename}")
        with open(file_path, 'wb') as f:
            f.write(content)

        result["saved"] = True
        result["file_path"] = file_path
        logger.info(f"[{push_id}] Saved file: {file_path} (size: {len(content)} bytes, checksum: {checksum})")

        # Validate file if enabled
        if VALIDATE_FILES:
            try:
                # Parse and validate JSON
                json_content = json.loads(content)

                # Count profiles
                if isinstance(json_content, list):
                    result["profile_count"] = len(json_content)
                elif isinstance(json_content, dict):
                    # Check if it's a wrapped format
                    if "AI-Security-Profiles" in json_content:
                        result["profile_count"] = len(json_content["AI-Security-Profiles"])
                    else:
                        result["profile_count"] = 1

                result["validated"] = True
                logger.info(f"[{push_id}] Validated file: {result['profile_count']} profiles")

            except json.JSONDecodeError as e:
                result["error"] = f"JSON validation failed: {str(e)}"
                logger.error(f"[{push_id}] Validation error: {result['error']}")

        # Delete file after validation if enabled
        if DELETE_AFTER_VALIDATION and result["validated"]:
            os.remove(file_path)
            result["deleted"] = True
            logger.info(f"[{push_id}] Deleted file after successful validation")

    except Exception as e:
        result["error"] = f"File processing error: {str(e)}"
        logger.error(f"[{push_id}] Processing error: {result['error']}")

    return result


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

@app.put("/file/{full_path:path}")
async def push_configuration_with_path(full_path: str, request: Request):
    """
    Receive and process a configuration push with file path

    This endpoint handles requests like:
    - PUT /file/opt/ns/tenant/{tenant_id}/aisecurityprofile.json
    - PUT /file/opt/ns/tenant/{tenant_id}/aisecurity_settings.json

    Args:
        full_path: Full file path (e.g., "opt/ns/tenant/1212/aisecurityprofile.json")
        request: FastAPI request object containing raw body

    Returns:
        Plain text response (matching CfgPusher behavior)
    """
    # Extract tenant_id and filename from path
    # Path format: opt/ns/tenant/{tenant_id}/{filename}
    path_parts = full_path.split("/")
    if len(path_parts) >= 4:
        tenant_id = path_parts[3]
        filename = path_parts[-1]
    else:
        tenant_id = "unknown"
        filename = full_path.split("/")[-1] if "/" in full_path else full_path

    logger.info(f"[PUT /file] Received push request: path={full_path}, tenant={tenant_id}, file={filename}")

    global push_counter
    push_counter += 1
    push_id = f"push-{push_counter:06d}"

    # Read raw body content
    content = await request.body()

    try:
        # Try to parse as JSON for validation
        json_content = json.loads(content)
        file_type = "json"
        profile_count = len(json_content) if isinstance(json_content, list) else 1
    except json.JSONDecodeError:
        file_type = "unknown"
        profile_count = 0

    logger.info(f"[{push_id}] Received push: {filename} (size: {len(content)} bytes, type: {file_type}, profiles: {profile_count})")

    # Save and validate file
    validation_result = save_and_validate_file(push_id, content, filename)

    # Update profile count from validation if available
    if validation_result["validated"]:
        profile_count = validation_result["profile_count"]

    # Determine status
    status = "completed" if validation_result["validated"] or not VALIDATE_FILES else "failed"

    # Store push information
    push_history[push_id] = {
        "push_id": push_id,
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "filename": filename,
        "file_path": full_path,
        "file_size": len(content),
        "file_type": file_type,
        "profile_count": profile_count,
        "tenant_id": tenant_id,
        "method": "PUT /file",
        "validation": validation_result
    }

    # Return plain text response (matching real CfgPusher)
    if status == "completed":
        return f"Configuration pushed successfully (push_id: {push_id}, {profile_count} profiles)"
    else:
        raise HTTPException(status_code=400, detail=f"Validation failed: {validation_result['error']}")


@app.put("/")
async def push_configuration_put(request: Request):
    """
    Receive and process a configuration push via PUT method (actual implementation)

    This endpoint matches the actual Profile API implementation which uses:
    - PUT method to root path
    - Content-Type: text/plain
    - Raw JSON body

    Args:
        request: FastAPI request object containing raw body

    Returns:
        Plain text response (matching CfgPusher behavior)
    """
    global push_counter
    push_counter += 1
    push_id = f"push-{push_counter:06d}"

    # Read raw body content
    content = await request.body()

    try:
        # Try to parse as JSON for validation
        json_content = json.loads(content)
        file_type = "json"
        profile_count = len(json_content) if isinstance(json_content, list) else 1

        # Extract filename from JSON content if available
        filename = "unknown"
        if isinstance(json_content, list) and len(json_content) > 0:
            first_item = json_content[0]
            if isinstance(first_item, dict):
                tenant_id = first_item.get("tenant_id", "unknown")
                filename = f"aisecurityprofile-{tenant_id}.json"

    except json.JSONDecodeError:
        file_type = "unknown"
        profile_count = 0
        filename = "unknown"
        tenant_id = "unknown"

    logger.info(f"[PUT] Received push: {push_id} (size: {len(content)} bytes, type: {file_type}, profiles: {profile_count})")

    # Save and validate file
    validation_result = save_and_validate_file(push_id, content, filename)

    # Update profile count from validation if available
    if validation_result["validated"]:
        profile_count = validation_result["profile_count"]

    # Determine status
    status = "completed" if validation_result["validated"] or not VALIDATE_FILES else "failed"

    # Store push information
    push_history[push_id] = {
        "push_id": push_id,
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "filename": filename,
        "file_size": len(content),
        "file_type": file_type,
        "profile_count": profile_count,
        "tenant_id": tenant_id,
        "method": "PUT",
        "validation": validation_result
    }

    # Return plain text response (matching real CfgPusher)
    if status == "completed":
        return f"Configuration pushed successfully (push_id: {push_id}, {profile_count} profiles)"
    else:
        raise HTTPException(status_code=400, detail=f"Validation failed: {validation_result['error']}")


@app.post("/push")
async def push_configuration_post(
    file: UploadFile = File(...),
    tenant_id: Optional[str] = None
):
    """
    Receive and process a configuration push via POST method (legacy/testing)

    This endpoint is kept for backward compatibility and manual testing.

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

    logger.info(f"[POST] Received push: {push_id} (file: {file.filename}, size: {len(content)} bytes, type: {file_type})")

    # Save and validate file
    validation_result = save_and_validate_file(push_id, content, file.filename or "unknown.json")

    # Update profile count from validation if available
    if validation_result["validated"]:
        profile_count = validation_result["profile_count"]

    # Determine status
    status = "completed" if validation_result["validated"] or not VALIDATE_FILES else "failed"

    # Store push information
    push_history[push_id] = {
        "push_id": push_id,
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "filename": file.filename,
        "file_size": len(content),
        "file_type": file_type,
        "profile_count": profile_count,
        "tenant_id": tenant_id,
        "method": "POST",
        "validation": validation_result
    }

    if status == "completed":
        return {
            "status": "success",
            "push_id": push_id,
            "message": f"Configuration pushed successfully ({profile_count} profiles)",
            "timestamp": push_history[push_id]["timestamp"],
            "validation": validation_result
        }
    else:
        raise HTTPException(status_code=400, detail=f"Validation failed: {validation_result['error']}")


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

    # Calculate statistics
    total_profiles = sum(p.get("profile_count", 0) for p in push_history.values())
    completed = sum(1 for p in push_history.values() if p.get("status") == "completed")
    failed = sum(1 for p in push_history.values() if p.get("status") == "failed")

    return {
        "total_pushes": len(push_history),
        "total_profiles": total_profiles,
        "completed": completed,
        "failed": failed,
        "recent_pushes": recent_pushes
    }


@app.get("/push/stats")
async def get_push_stats():
    """
    Get detailed push statistics

    Returns:
        dict: Detailed statistics about push operations
    """
    logger.info("Push statistics requested")

    # Calculate statistics
    total_profiles = sum(p.get("profile_count", 0) for p in push_history.values())
    total_size = sum(p.get("file_size", 0) for p in push_history.values())
    completed = sum(1 for p in push_history.values() if p.get("status") == "completed")
    failed = sum(1 for p in push_history.values() if p.get("status") == "failed")

    # Count saved and deleted files
    saved_count = sum(1 for p in push_history.values()
                     if p.get("validation", {}).get("saved", False))
    deleted_count = sum(1 for p in push_history.values()
                       if p.get("validation", {}).get("deleted", False))

    # Current files in storage
    storage_files = []
    if os.path.exists(STORAGE_DIR):
        storage_files = [f for f in os.listdir(STORAGE_DIR) if os.path.isfile(os.path.join(STORAGE_DIR, f))]

    return {
        "total_pushes": len(push_history),
        "total_profiles": total_profiles,
        "total_size_bytes": total_size,
        "total_size_mb": round(total_size / 1024 / 1024, 2),
        "status": {
            "completed": completed,
            "failed": failed
        },
        "files": {
            "saved": saved_count,
            "deleted": deleted_count,
            "in_storage": len(storage_files)
        },
        "storage_dir": STORAGE_DIR,
        "validate_enabled": VALIDATE_FILES,
        "delete_after_validation": DELETE_AFTER_VALIDATION
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

@app.get("/info")
async def root():
    """
    Service information endpoint

    Returns:
        dict: Service information
    """
    return {
        "service": "Mock Push Service",
        "version": "1.0.0",
        "description": "Mock Configuration Push Service for local development",
        "endpoints": {
            "health": "GET /healthcheck",
            "push_put": "PUT / (actual implementation)",
            "push_post": "POST /push (legacy/testing)",
            "status": "GET /push/status/{push_id}",
            "history": "GET /push/history",
            "clear": "DELETE /push/clear",
            "info": "GET /info"
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
