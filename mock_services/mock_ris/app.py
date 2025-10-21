"""
Mock RIS (Reference Integration Service) Service

This service provides a mock implementation of the RIS API for local development.
It simulates the reference object management without actual backend persistence.

API Endpoints:
- GET  /healthcheck - Health check endpoint
- PUT  /internal/v1/objects/aisecurityprofile/{profile_id} - Create reference
- DELETE /internal/v1/objects/aisecurityprofile/{profile_id} - Delete reference
- GET  /internal/v1/objects/aisecurityprofile/{profile_id}/references - Check dependencies
- POST /internal/v1/objects/aisecurityprofile/bulk - Bulk operations
"""

from fastapi import FastAPI, Header, Request, HTTPException
from typing import Dict, List, Optional
import logging
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI(
    title="Mock RIS Service",
    description="Mock Reference Integration Service for local development",
    version="1.0.0"
)

# In-memory storage for reference objects
# Format: {tenant_id:profile_id: {profile_id, tenant_id, caller_id}}
reference_store: Dict[str, Dict[str, any]] = {}


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
        "service": "mock-ris",
        "version": "1.0.0",
        "stored_references": len(reference_store)
    }


# ========================= REFERENCE MANAGEMENT =========================#

@app.put("/internal/v1/objects/aisecurityprofile/{profile_id}")
async def create_reference(
    profile_id: str,
    x_netskope_caller_id: str = Header(..., alias="x-netskope-caller-id"),
    x_netskope_tenantid: str = Header(..., alias="x-netskope-tenantid"),
    x_netskope_request_id: str = Header(default="1", alias="x-netskope-request-id")
):
    """
    Create RIS object reference for a profile

    Args:
        profile_id: Profile identifier
        x_netskope_caller_id: Caller service ID (header)
        x_netskope_tenantid: Tenant identifier (header)
        x_netskope_request_id: Request identifier (header)

    Returns:
        dict: Operation status
    """
    key = f"{x_netskope_tenantid}:{profile_id}"
    logger.info(f"[RIS CREATE] Received request for profile_id={profile_id}, tenant={x_netskope_tenantid}, caller={x_netskope_caller_id}")
    logger.info(f"[RIS CREATE] Current stored_references count: {len(reference_store)}")

    reference_store[key] = {
        "profile_id": profile_id,
        "tenant_id": x_netskope_tenantid,
        "caller_id": x_netskope_caller_id,
        "request_id": x_netskope_request_id
    }

    logger.info(f"[RIS CREATE] ✓ Reference created successfully for {key}")
    logger.info(f"[RIS CREATE] New stored_references count: {len(reference_store)}")
    return {
        "status": "created",
        "profile_id": profile_id,
        "tenant_id": x_netskope_tenantid
    }


@app.delete("/internal/v1/objects/aisecurityprofile/{profile_id}")
async def delete_reference(
    profile_id: str,
    x_netskope_caller_id: str = Header(..., alias="x-netskope-caller-id"),
    x_netskope_tenantid: str = Header(..., alias="x-netskope-tenantid"),
    x_netskope_request_id: str = Header(default="1", alias="x-netskope-request-id")
):
    """
    Delete RIS object reference for a profile

    Args:
        profile_id: Profile identifier
        x_netskope_caller_id: Caller service ID (header)
        x_netskope_tenantid: Tenant identifier (header)
        x_netskope_request_id: Request identifier (header)

    Returns:
        dict: Operation status
    """
    key = f"{x_netskope_tenantid}:{profile_id}"
    logger.info(f"[RIS DELETE] Received request for profile_id={profile_id}, tenant={x_netskope_tenantid}, caller={x_netskope_caller_id}")
    logger.info(f"[RIS DELETE] Current stored_references count: {len(reference_store)}")

    if key in reference_store:
        del reference_store[key]
        logger.info(f"[RIS DELETE] ✓ Reference deleted successfully for {key}")
        logger.info(f"[RIS DELETE] New stored_references count: {len(reference_store)}")
    else:
        logger.info(f"[RIS DELETE] ⚠ Reference not found for {key} (already deleted or never existed)")
        logger.info(f"[RIS DELETE] stored_references count unchanged: {len(reference_store)}")

    return {
        "status": "deleted",
        "profile_id": profile_id,
        "tenant_id": x_netskope_tenantid
    }


@app.get("/internal/v1/objects/aisecurityprofile/{profile_id}/references")
async def get_references(
    profile_id: str,
    x_netskope_caller_id: str = Header(..., alias="x-netskope-caller-id"),
    x_netskope_tenantid: str = Header(..., alias="x-netskope-tenantid"),
    x_netskope_request_id: str = Header(default="1", alias="x-netskope-request-id")
):
    """
    Check if profile has dependencies that prevent deletion

    Mock implementation always returns no dependencies.

    Args:
        profile_id: Profile identifier
        x_netskope_caller_id: Caller service ID (header)
        x_netskope_tenantid: Tenant identifier (header)
        x_netskope_request_id: Request identifier (header)

    Returns:
        dict: Reference information
    """
    logger.info(f"Checking references for profile {profile_id} (tenant: {x_netskope_tenantid})")

    # Mock implementation: always return no dependencies
    # This allows all delete operations to proceed
    return {
        "references": []
    }


# ========================= BULK OPERATIONS =========================#

@app.post("/internal/v1/objects/aisecurityprofile/bulk")
async def bulk_operations(
    request: Request,
    x_netskope_caller_id: str = Header(..., alias="x-netskope-caller-id"),
    x_netskope_tenantid: str = Header(..., alias="x-netskope-tenantid"),
    x_netskope_request_id: str = Header(default="1", alias="x-netskope-request-id")
):
    """
    Bulk create/delete RIS objects

    Request body format:
    {
        "create": ["profile-id-1", "profile-id-2"],
        "delete": ["profile-id-3", "profile-id-4"]
    }

    Args:
        request: FastAPI request object
        x_netskope_caller_id: Caller service ID (header)
        x_netskope_tenantid: Tenant identifier (header)
        x_netskope_request_id: Request identifier (header)

    Returns:
        dict: Bulk operation results
    """
    body = await request.json()
    create_ids = body.get("create", [])
    delete_ids = body.get("delete", [])

    logger.info(f"Bulk operation requested: create={len(create_ids)}, delete={len(delete_ids)} (tenant: {x_netskope_tenantid})")

    # Process create operations
    created_ids = []
    for pid in create_ids:
        key = f"{x_netskope_tenantid}:{pid}"
        reference_store[key] = {
            "profile_id": pid,
            "tenant_id": x_netskope_tenantid,
            "caller_id": x_netskope_caller_id
        }
        created_ids.append(pid)

    # Process delete operations
    deleted_ids = []
    for pid in delete_ids:
        key = f"{x_netskope_tenantid}:{pid}"
        if key in reference_store:
            del reference_store[key]
            deleted_ids.append(pid)
        else:
            # Still count as success even if not found (idempotent)
            deleted_ids.append(pid)

    logger.info(f"Bulk operation completed: created={len(created_ids)}, deleted={len(deleted_ids)}")

    return {
        "created_ids": created_ids,
        "deleted_ids": deleted_ids
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
        "service": "Mock RIS Service",
        "version": "1.0.0",
        "description": "Mock Reference Integration Service for local development",
        "endpoints": {
            "health": "/healthcheck",
            "create": "PUT /internal/v1/objects/aisecurityprofile/{profile_id}",
            "delete": "DELETE /internal/v1/objects/aisecurityprofile/{profile_id}",
            "references": "GET /internal/v1/objects/aisecurityprofile/{profile_id}/references",
            "bulk": "POST /internal/v1/objects/aisecurityprofile/bulk"
        },
        "stored_references": len(reference_store)
    }


# ========================= APPLICATION STARTUP =========================#

if __name__ == "__main__":
    logger.info("Starting Mock RIS Service on port 8080...")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info"
    )
