"""
Test Mock RIS Service

This script tests the Mock RIS Service endpoints to ensure proper functionality.
"""

import requests
import sys

BASE_URL = "http://localhost:30082"


def test_healthcheck():
    """Test health check endpoint"""
    print("Testing /healthcheck...")
    response = requests.get(f"{BASE_URL}/healthcheck")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "healthy", f"Expected healthy status, got {data['status']}"
    assert data["service"] == "mock-ris", f"Expected mock-ris service, got {data['service']}"

    print("✅ Health check passed")
    return True


def test_create_reference():
    """Test creating a reference"""
    print("\nTesting PUT /internal/v1/objects/aisecurityprofile/{profile_id}...")

    headers = {
        "x-netskope-caller-id": "test-caller",
        "x-netskope-tenantid": "test-tenant-001",
        "x-netskope-request-id": "req-001"
    }

    response = requests.put(
        f"{BASE_URL}/internal/v1/objects/aisecurityprofile/profile-001",
        headers=headers
    )

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "created", f"Expected 'created' status, got {data['status']}"
    assert data["profile_id"] == "profile-001", f"Expected profile-001, got {data['profile_id']}"

    print("✅ Create reference passed")
    return True


def test_get_references():
    """Test checking references (dependencies)"""
    print("\nTesting GET /internal/v1/objects/aisecurityprofile/{profile_id}/references...")

    headers = {
        "x-netskope-caller-id": "test-caller",
        "x-netskope-tenantid": "test-tenant-001",
        "x-netskope-request-id": "req-002"
    }

    response = requests.get(
        f"{BASE_URL}/internal/v1/objects/aisecurityprofile/profile-001/references",
        headers=headers
    )

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "references" in data, "Expected 'references' field in response"
    assert isinstance(data["references"], list), "Expected 'references' to be a list"
    # Mock always returns empty references
    assert len(data["references"]) == 0, "Expected empty references list from mock"

    print("✅ Get references passed")
    return True


def test_delete_reference():
    """Test deleting a reference"""
    print("\nTesting DELETE /internal/v1/objects/aisecurityprofile/{profile_id}...")

    headers = {
        "x-netskope-caller-id": "test-caller",
        "x-netskope-tenantid": "test-tenant-001",
        "x-netskope-request-id": "req-003"
    }

    response = requests.delete(
        f"{BASE_URL}/internal/v1/objects/aisecurityprofile/profile-001",
        headers=headers
    )

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "deleted", f"Expected 'deleted' status, got {data['status']}"
    assert data["profile_id"] == "profile-001", f"Expected profile-001, got {data['profile_id']}"

    print("✅ Delete reference passed")
    return True


def test_bulk_operations():
    """Test bulk create/delete operations"""
    print("\nTesting POST /internal/v1/objects/aisecurityprofile/bulk...")

    headers = {
        "x-netskope-caller-id": "test-caller",
        "x-netskope-tenantid": "test-tenant-002",
        "x-netskope-request-id": "req-004"
    }

    payload = {
        "create": ["profile-002", "profile-003", "profile-004"],
        "delete": ["profile-005", "profile-006"]
    }

    response = requests.post(
        f"{BASE_URL}/internal/v1/objects/aisecurityprofile/bulk",
        json=payload,
        headers=headers
    )

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "created_ids" in data, "Expected 'created_ids' field in response"
    assert "deleted_ids" in data, "Expected 'deleted_ids' field in response"
    assert len(data["created_ids"]) == 3, f"Expected 3 created IDs, got {len(data['created_ids'])}"
    assert len(data["deleted_ids"]) == 2, f"Expected 2 deleted IDs, got {len(data['deleted_ids'])}"

    print("✅ Bulk operations passed")
    return True


def test_root_endpoint():
    """Test root endpoint"""
    print("\nTesting GET /...")

    response = requests.get(f"{BASE_URL}/")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["service"] == "Mock RIS Service", f"Expected 'Mock RIS Service', got {data['service']}"
    assert "endpoints" in data, "Expected 'endpoints' field in response"

    print("✅ Root endpoint passed")
    return True


def main():
    """Run all tests"""
    print("=" * 60)
    print("Mock RIS Service Tests")
    print("=" * 60)

    tests = [
        test_healthcheck,
        test_root_endpoint,
        test_create_reference,
        test_get_references,
        test_delete_reference,
        test_bulk_operations
    ]

    failed = 0
    for test_func in tests:
        try:
            test_func()
        except Exception as e:
            print(f"❌ Test failed: {e}")
            failed += 1

    print("\n" + "=" * 60)
    if failed == 0:
        print("✅ All tests passed!")
        print("=" * 60)
        return 0
    else:
        print(f"❌ {failed} test(s) failed")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())
