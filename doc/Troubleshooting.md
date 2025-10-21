# Troubleshooting Guide

> **Language**: [English](Troubleshooting.md) | [繁體中文](zh_tw/Troubleshooting.md)

This guide helps you diagnose and resolve common issues with the Local Stack environment.

## Table of Contents

- [Cluster Issues](#cluster-issues)
- [MongoDB Issues](#mongodb-issues)
- [Management Service Issues](#management-service-issues)
- [Mock Service Issues](#mock-service-issues)
- [Network and Connectivity Issues](#network-and-connectivity-issues)
- [Image and Registry Issues](#image-and-registry-issues)
- [Health Check Issues](#health-check-issues)

---

## Cluster Issues

### Issue: k3d cluster not found

**Symptom**:
```bash
Error: No cluster found for context k3d-local-dev
```

**Solution**:
```bash
# Check if cluster exists
k3d cluster list

# If not found, create the cluster
cd k3d
./setup-k3d-cluster.sh
```

### Issue: Cluster creation fails

**Symptom**:
```bash
Error: failed to create cluster: port 30080 is already allocated
```

**Solution**:
```bash
# Check what's using the port
lsof -i :30080

# If it's another k3d cluster, delete it
k3d cluster delete <cluster-name>

# If it's another process, stop it or change port in setup script
```

### Issue: kubectl can't connect to cluster

**Symptom**:
```bash
The connection to the server localhost:8080 was refused
```

**Solution**:
```bash
# Switch to correct context
kubectl config use-context k3d-local-dev

# Verify cluster is running
k3d cluster list

# If not running, start it
k3d cluster start local-dev
```

---

## MongoDB Issues

### Issue: MongoDB pod not starting

**Symptom**:
```bash
kubectl get pods
# mongodb-xxx  0/1  CrashLoopBackOff
```

**Solution**:
```bash
# Check pod logs
kubectl logs -l app=mongodb

# Common causes:
# 1. Insufficient resources - increase Docker Desktop memory
# 2. Port conflict - check if port 27017 is in use
# 3. Volume mount issues - delete and recreate deployment

# Restart MongoDB
cd mongoDB
./cleanup-DB.sh
./setup-DB.sh
```

### Issue: Can't connect to MongoDB from mgmt-service

**Symptom**:
```bash
# Health check shows MongoDB unhealthy
{
  "mongodb": {"status": "unhealthy", "error": "Connection timeout"}
}
```

**Solution**:
```bash
# 1. Verify MongoDB is running
kubectl get pods -l app=mongodb

# 2. Check MongoDB service
kubectl get svc mongodb-service

# 3. Test connection from within cluster
kubectl run -it --rm debug --image=mongo:latest --restart=Never -- \
  mongo mongodb-service:27017 -u <username> -p <password>

# 4. Verify credentials in env/host_info.txt
echo $DB_ACCOUNT | base64 -d  # Should decode correctly
echo $DB_CREDENT | base64 -d  # Should decode correctly
```

### Issue: MongoDB credentials not working

**Symptom**:
```bash
Authentication failed
```

**Solution**:
```bash
# 1. Check env/host_info.txt credentials
cat env/host_info.txt

# 2. Verify base64 encoding is correct
echo -n "username" | base64  # Use -n to avoid newline
echo -n "password" | base64

# 3. Update host_info.txt with correct values

# 4. Restart mgmt-service to pick up new credentials
./reload.sh
```

---

## Management Service Issues

### Issue: Management service pods not ready

**Symptom**:
```bash
kubectl get pods
# aisecurity-mgmt-service-xxx  0/1  Running
```

**Solution**:
```bash
# 1. Check pod logs
kubectl logs -l app=aisecurity-mgmt-service

# 2. Common errors and solutions:
# - "ModuleNotFoundError: No module named 'X'" → requirements.txt issue
# - "Can't connect to MongoDB" → Check MongoDB section above
# - "Permission denied" → Check file permissions in Docker image

# 3. Rebuild and redeploy
./reload.sh
```

### Issue: Health check fails after deployment

**Symptom**:
```bash
curl http://localhost:30080/health/liveness
# Connection refused
```

**Solution**:
```bash
# 1. Wait for pods to be fully ready (can take 30-60 seconds)
kubectl wait --for=condition=ready pod -l app=aisecurity-mgmt-service --timeout=120s

# 2. Check pod status
kubectl get pods -l app=aisecurity-mgmt-service

# 3. Check service
kubectl get svc aisecurity-mgmt-service-service

# 4. Port forward for debugging
kubectl port-forward svc/aisecurity-mgmt-service-service 8000:8000
curl http://localhost:8000/health/liveness
```

### Issue: API returns 404

**Symptom**:
```bash
curl http://localhost:30080/aisecurity/api/v1/profiles
# 404 Not Found
```

**Solution**:
```bash
# 1. Verify correct base path
# Correct: /aisecurity/api/v1/profiles
# Wrong: /profiles

# 2. Check FastAPI docs for available endpoints
open http://localhost:30080/docs

# 3. Verify service is using correct port
kubectl describe svc aisecurity-mgmt-service-service
```

---

## Mock Service Issues

### Issue: Mock RIS service not responding

**Symptom**:
```bash
curl http://localhost:30082/healthcheck
# Connection refused
```

**Solution**:
```bash
# 1. Check if pod is running
kubectl get pods -l app=mock-ris

# 2. Check logs
kubectl logs -l app=mock-ris

# 3. Restart service
kubectl rollout restart deployment/mock-ris-deployment

# 4. If still failing, redeploy
cd mock_services/mock_ris
./buildimg.sh
kubectl delete -f deployment.yaml -f service.yaml
kubectl apply -f deployment.yaml -f service.yaml
```

### Issue: Mock Push service health check fails

**Symptom**:
```bash
# mgmt-service health check shows Push API unhealthy
{
  "pusher_api": {"status": "unhealthy"}
}
```

**Solution**:
```bash
# 1. Verify Mock Push is running
kubectl get pods -l app=mock-push

# 2. Test directly
curl http://localhost:30083/healthcheck

# 3. Check service endpoint in env/host_info.txt
# Should be: PUSHER_API_URL=http://mock-push-service:5002

# 4. Restart mgmt-service
kubectl rollout restart deployment/aisecurity-mgmt-service
```

### Issue: Mock service tests failing

**Symptom**:
```bash
python3 test/test_mock_ris.py
# ❌ Test failed: Connection refused
```

**Solution**:
```bash
# 1. Ensure services are deployed
./setup-mock-services.sh

# 2. Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=mock-ris --timeout=60s
kubectl wait --for=condition=ready pod -l app=mock-push --timeout=60s

# 3. Verify ports are accessible
curl http://localhost:30082/healthcheck
curl http://localhost:30083/healthcheck

# 4. Run tests again
cd test
python3 test_mock_ris.py
python3 test_mock_push.py
```

---

## Network and Connectivity Issues

### Issue: Port already in use

**Symptom**:
```bash
Error: port 30080 is already allocated
```

**Solution**:
```bash
# Find what's using the port
lsof -i :30080

# Kill the process or change port mapping
# To change port, edit k3d/setup-k3d-cluster.sh
# Change: -p "30080:30080@loadbalancer"
# To: -p "30090:30080@loadbalancer"
```

### Issue: Can't access service from host

**Symptom**:
```bash
curl http://localhost:30080/health/liveness
# No route to host
```

**Solution**:
```bash
# 1. Verify port mapping
k3d cluster list
# Should show: 0.0.0.0:30080->30080/TCP

# 2. Check if service is NodePort type
kubectl get svc aisecurity-mgmt-service-service
# TYPE should be NodePort

# 3. Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://aisecurity-mgmt-service-service:8000/health/liveness
```

### Issue: Services can't communicate with each other

**Symptom**:
```bash
# mgmt-service can't reach Mock RIS
Error: failed to connect to http://mock-ris-service:5001
```

**Solution**:
```bash
# 1. Verify service DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup mock-ris-service

# 2. Check service endpoints
kubectl get endpoints mock-ris-service

# 3. Verify service ports
kubectl get svc mock-ris-service
# Should show: PORT 5001/TCP

# 4. Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://mock-ris-service:5001/healthcheck
```

---

## Image and Registry Issues

### Issue: Image pull failed

**Symptom**:
```bash
kubectl get pods
# aisecurity-mgmt-service-xxx  0/1  ImagePullBackOff
```

**Solution**:
```bash
# 1. Check if image exists in local registry
docker images | grep k3d-local-img

# 2. Rebuild and push image
./reload.sh

# 3. Verify image was pushed
docker images | grep aisecurity-mgmt-service

# 4. Delete failing pod (will auto-recreate)
kubectl delete pod <pod-name>
```

### Issue: Docker build fails

**Symptom**:
```bash
./reload.sh
# ERROR: failed to solve: process "/bin/sh -c pip install..." did not complete successfully
```

**Solution**:
```bash
# 1. Check requirements.txt exists
ls -la pkg/requirements.txt

# 2. Verify requirements.txt is copied correctly
# Check pkg/requirements.txt vs deployments/DockerImage/aisecurity-mgmt-service/requirements.txt

# 3. Test requirements.txt locally
pip install -r pkg/requirements.txt

# 4. Check Docker Desktop has enough resources
# Settings → Resources → Increase memory to at least 4GB
```

### Issue: Registry push fails

**Symptom**:
```bash
docker push k3d-local-img:5555/aisecurity-mgmt-service:local-dev
# Error: connection refused
```

**Solution**:
```bash
# 1. Verify k3d registry is running
docker ps | grep k3d-local-img-registry

# 2. If not running, recreate cluster
cd k3d
./cleanup-k3d.sh
./setup-k3d-cluster.sh

# 3. Retry push
./reload.sh
```

---

## Health Check Issues

### Issue: Readiness probe failing

**Symptom**:
```bash
kubectl describe pod <pod-name>
# Readiness probe failed: Get "http://...": context deadline exceeded
```

**Solution**:
```bash
# 1. Check if dependencies are healthy
curl http://localhost:30080/health/liveness

# 2. Increase probe timeout in deployment.yaml
# Change: timeoutSeconds: 5
# To: timeoutSeconds: 10

# 3. Check MongoDB connectivity
kubectl logs -l app=aisecurity-mgmt-service | grep -i mongo

# 4. Verify Mock Services are running
kubectl get pods -l 'app in (mock-ris,mock-push)'
```

### Issue: Health check shows degraded status

**Symptom**:
```json
{
  "overall_status": "degraded",
  "services": {
    "mongodb": {"status": "healthy"},
    "ris_api": {"status": "unhealthy"},
    "pusher_api": {"status": "healthy"}
  }
}
```

**Solution**:
```bash
# 1. Identify which service is unhealthy (ris_api in this case)

# 2. Check RIS service
kubectl get pods -l app=mock-ris
kubectl logs -l app=mock-ris

# 3. Verify RIS service endpoint
curl http://localhost:30082/healthcheck

# 4. Check mgmt-service configuration
# Verify PUSHER_API_URL in env/host_info.txt

# 5. Restart unhealthy service
kubectl rollout restart deployment/mock-ris-deployment
```

---

## General Debugging Tips

### Get Overall System Status

```bash
# Check all resources
kubectl get all

# Check all pods with labels
kubectl get pods -l 'app in (aisecurity-mgmt-service,mock-ris,mock-push,mongodb,mongo-express)'

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### View Logs

```bash
# Management service logs
kubectl logs -l app=aisecurity-mgmt-service --tail=100 -f

# MongoDB logs
kubectl logs -l app=mongodb --tail=100

# Mock RIS logs
kubectl logs -l app=mock-ris --tail=100

# Mock Push logs
kubectl logs -l app=mock-push --tail=100
```

### Complete Environment Reset

If all else fails, reset the entire environment:

```bash
# 1. Clean up everything
./cleanup-mock-services.sh
./clean_aisecurity_profile_api.sh
cd mongoDB && ./cleanup-DB.sh && cd ..
cd k3d && ./cleanup-k3d.sh && cd ..

# 2. Recreate from scratch
cd k3d && ./setup-k3d-cluster.sh && cd ..
cd mongoDB && ./setup-DB.sh && cd ..
./setup-mock-services.sh
./reload.sh

# 3. Verify everything is working
kubectl get pods
curl http://localhost:30080/health/liveness
```

### Enable Debug Logging

Edit `pkg/Dockerfile` or deployment environment variables:

```yaml
env:
  - name: LOG_LEVEL
    value: "DEBUG"
  - name: PYTHONUNBUFFERED
    value: "1"
```

Then redeploy:
```bash
./reload.sh
```

---

## Getting Help

If you're still experiencing issues:

1. **Check Pod Status**: `kubectl get pods` - Are all pods Running and Ready?
2. **Check Logs**: `kubectl logs <pod-name>` - What errors are shown?
3. **Check Events**: `kubectl get events --sort-by='.lastTimestamp'` - Any recent errors?
4. **Check Health**: `curl http://localhost:30080/health/liveness` - What's the status?
5. **Check Network**: Can services reach each other? Test with debug pods.

Document your findings and share with the team for assistance.

---

## Related Documentation

- [README.md](README.md) - Setup and usage guide
- [Architecture.md](Architecture.md) - System architecture details
- [繁體中文文檔](zh_tw/Troubleshooting.md) - Traditional Chinese version
