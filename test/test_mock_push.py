"""
Test Mock Push Service

This script tests the Mock Push Service endpoints to ensure proper functionality.
"""

import requests
import sys
import json
import io

BASE_URL = "http://localhost:30083"


def test_healthcheck():
    """Test health check endpoint"""
    print("Testing /healthcheck...")
    response = requests.get(f"{BASE_URL}/healthcheck")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "healthy", f"Expected healthy status, got {data['status']}"
    assert data["service"] == "mock-push", f"Expected mock-push service, got {data['service']}"

    print("✅ Health check passed")
    return True


def test_push_configuration():
    """Test pushing a configuration file"""
    print("\nTesting POST /push...")

    # Create a sample configuration JSON
    config_data = [
        {
            "profile_id": "test-profile-001",
            "name": "Test Profile 1",
            "enabled": True
        },
        {
            "profile_id": "test-profile-002",
            "name": "Test Profile 2",
            "enabled": True
        }
    ]

    # Create file-like object
    json_content = json.dumps(config_data, indent=2)
    file_obj = io.BytesIO(json_content.encode('utf-8'))

    files = {
        'file': ('test_config.json', file_obj, 'application/json')
    }

    data = {
        'tenant_id': 'test-tenant-001'
    }

    response = requests.post(f"{BASE_URL}/push", files=files, data=data)

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    result = response.json()
    assert result["status"] == "success", f"Expected 'success' status, got {result['status']}"
    assert "push_id" in result, "Expected 'push_id' field in response"
    assert "message" in result, "Expected 'message' field in response"
    # Verify message contains profile count information
    assert "profiles" in result["message"].lower(), "Expected message to mention profiles"

    print(f"✅ Push configuration passed (Push ID: {result['push_id']})")
    return result["push_id"]


def test_get_push_status(push_id):
    """Test getting push status"""
    print(f"\nTesting GET /push/status/{push_id}...")

    response = requests.get(f"{BASE_URL}/push/status/{push_id}")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["push_id"] == push_id, f"Expected push_id {push_id}, got {data['push_id']}"
    assert data["status"] == "completed", f"Expected 'completed' status, got {data['status']}"
    assert "timestamp" in data, "Expected 'timestamp' field in response"

    print("✅ Get push status passed")
    return True


def test_get_push_status_not_found():
    """Test getting status for non-existent push"""
    print("\nTesting GET /push/status/{invalid_id}...")

    response = requests.get(f"{BASE_URL}/push/status/invalid-push-id")

    assert response.status_code == 404, f"Expected 404, got {response.status_code}"

    print("✅ Get push status (not found) passed")
    return True


def test_get_push_history():
    """Test getting push history"""
    print("\nTesting GET /push/history...")

    response = requests.get(f"{BASE_URL}/push/history?limit=5")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert "total_pushes" in data, "Expected 'total_pushes' field in response"
    assert "recent_pushes" in data, "Expected 'recent_pushes' field in response"
    assert isinstance(data["recent_pushes"], list), "Expected 'recent_pushes' to be a list"

    print(f"✅ Get push history passed (Total: {data['total_pushes']} pushes)")
    return True


def test_root_endpoint():
    """Test root endpoint"""
    print("\nTesting GET /...")

    response = requests.get(f"{BASE_URL}/")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["service"] == "Mock Push Service", f"Expected 'Mock Push Service', got {data['service']}"
    assert "endpoints" in data, "Expected 'endpoints' field in response"
    assert "statistics" in data, "Expected 'statistics' field in response"

    print("✅ Root endpoint passed")
    return True


def test_clear_history():
    """Test clearing push history"""
    print("\nTesting DELETE /push/clear...")

    response = requests.delete(f"{BASE_URL}/push/clear")

    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    data = response.json()
    assert data["status"] == "success", f"Expected 'success' status, got {data['status']}"
    assert "cleared_records" in data, "Expected 'cleared_records' field in response"

    print(f"✅ Clear history passed (Cleared: {data['cleared_records']} records)")
    return True


def main():
    """Run all tests"""
    print("=" * 60)
    print("Mock Push Service Tests")
    print("=" * 60)

    failed = 0
    push_id = None

    # Test health and root
    tests_basic = [
        test_healthcheck,
        test_root_endpoint
    ]

    for test_func in tests_basic:
        try:
            test_func()
        except Exception as e:
            print(f"❌ Test failed: {e}")
            failed += 1

    # Test push operations (these depend on each other)
    try:
        push_id = test_push_configuration()
        test_get_push_status(push_id)
        test_get_push_status_not_found()
        test_get_push_history()
        test_clear_history()
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
