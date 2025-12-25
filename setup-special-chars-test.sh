#!/bin/bash
#
# Setup MongoDB with special character credentials for testing
#
# This script configures k3d MongoDB to use credentials with special characters
# to test the PR fix for ENG-804500 (handle special characters in username/password)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test credentials (containing @, :, /, ?, #)
TEST_USERNAME="admin@user:test"
TEST_PASSWORD="p@ss:w/rd?test#123"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}MongoDB Special Characters Auth Test${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# 1. Generate base64 encoded credentials
echo -e "${YELLOW}Step 1: Generating base64 encoded credentials...${NC}"
ENCODED_USERNAME=$(echo -n "$TEST_USERNAME" | base64)
ENCODED_PASSWORD=$(echo -n "$TEST_PASSWORD" | base64)

echo "Username: $TEST_USERNAME"
echo "Password: $TEST_PASSWORD"
echo "Encoded Username: $ENCODED_USERNAME"
echo "Encoded Password: $ENCODED_PASSWORD"
echo ""

# 2. Backup original secret
echo -e "${YELLOW}Step 2: Backing up original mongodb-secret.yaml...${NC}"
SECRET_FILE="mongoDB/deployment/mongodb-secret.yaml"
BACKUP_FILE="mongoDB/deployment/mongodb-secret.yaml.backup"

if [ -f "$SECRET_FILE" ]; then
    cp "$SECRET_FILE" "$BACKUP_FILE"
    echo "Backup saved to: $BACKUP_FILE"
else
    echo -e "${RED}Error: $SECRET_FILE not found${NC}"
    exit 1
fi
echo ""

# 3. Update secret with special characters
echo -e "${YELLOW}Step 3: Updating mongodb-secret.yaml with special characters...${NC}"
cat > "$SECRET_FILE" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: local-stack
type: Opaque
data:
  mongo-root-username: $ENCODED_USERNAME
  mongo-root-password: $ENCODED_PASSWORD
EOF

echo "Secret updated successfully"
echo ""

# 4. Update test configuration
echo -e "${YELLOW}Step 4: Updating test configuration...${NC}"
TEST_CONFIG="../test/e2e_test/config_env.py"

if [ -f "$TEST_CONFIG" ]; then
    # Backup config
    cp "$TEST_CONFIG" "$TEST_CONFIG.backup"

    # Update credentials
    sed -i '' "s/\"MONGODB_USERNAME\": \".*\"/\"MONGODB_USERNAME\": \"$TEST_USERNAME\"/" "$TEST_CONFIG"
    sed -i '' "s/\"MONGODB_PASSWORD\": \".*\"/\"MONGODB_PASSWORD\": \"$TEST_PASSWORD\"/" "$TEST_CONFIG"

    echo "Test config updated successfully"
else
    echo -e "${YELLOW}Warning: Test config not found at $TEST_CONFIG${NC}"
fi
echo ""

# 5. Deploy MongoDB
echo -e "${YELLOW}Step 5: Deploying MongoDB with special character credentials...${NC}"
echo "Cleaning up existing MongoDB deployment..."
./mongoDB/cleanup-DB.sh

echo ""
echo "Deploying MongoDB..."
./mongoDB/setup-DB.sh

echo ""

# 6. Reload service
echo -e "${YELLOW}Step 6: Reloading service...${NC}"
./reload.sh

echo ""

# 7. Wait for service to be ready
echo -e "${YELLOW}Step 7: Waiting for service to be ready...${NC}"
echo "Waiting 30 seconds for pods to start..."
sleep 30

# Check pod status
kubectl get pods -n local-stack -l app=aisecurity-mgmt-service

echo ""

# 8. Instructions for testing
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "MongoDB is now configured with special character credentials:"
echo "  Username: $TEST_USERNAME"
echo "  Password: $TEST_PASSWORD"
echo ""
echo "To run the test:"
echo "  cd .."
echo "  python3 test/e2e_test/test_e2e_special_chars_auth.py -v"
echo ""
echo "To check service health:"
echo "  curl http://localhost:30080/health/readiness"
echo ""
echo "To restore original credentials:"
echo "  cp mongoDB/deployment/mongodb-secret.yaml.backup mongoDB/deployment/mongodb-secret.yaml"
echo "  cp test/e2e_test/config_env.py.backup test/e2e_test/config_env.py"
echo "  ./mongoDB/cleanup-DB.sh && ./mongoDB/setup-DB.sh && ./reload.sh"
echo ""
