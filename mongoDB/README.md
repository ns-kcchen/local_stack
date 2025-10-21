# MongoDB Stack for Profile API

This directory contains MongoDB and Mongo Express deployment configurations for the Profile API project, using both traditional Kubernetes manifests and modern Helm charts.

## 🚀 Quick Start

### Option 1: Deploy Complete Stack (Recommended)

```bash
# Deploy both MongoDB and Mongo Express with one command
./setup-DB.sh
```

### Option 2: Deploy Individual Components

```bash
# Deploy MongoDB first
./deploy-mongoDB.sh

# Then deploy Mongo Express
./deploy-mongoExpress.sh
```

## 🌐 Access Points

After deployment, you can access:

- **Profile API**: http://localhost:30080
- **Mongo Express (Web UI)**: http://localhost:30081
- **MongoDB (Internal)**: `mongodb-service:27017`

## 🔑 Credentials

- **Username**: `username`
- **Password**: `password`
- **Connection String**: `mongodb://username:password@mongodb-service:27017/`

## 📁 Directory Structure

```
mongoDB/
├── deploy-mongoDB.sh                    # Deploy MongoDB with Helm
├── deploy-mongoExpress.sh               # Deploy Mongo Express with Helm
├── setup-DB.sh                         # Deploy complete stack
├── cleanup-DB.sh                       # Cleanup complete stack
├── deployment/                          # Legacy Kubernetes manifests
│   ├── mongodb-secret.yaml            
│   ├── mongodb-configmap.yaml         
│   ├── mongodb-deployment.yaml        
│   ├── mongo-express-deployment.yaml  
│   └── mongo-express-nodeport.yaml    
├── helm-chart/                          # Helm charts (recommended)
│   ├── mongodb/                        # MongoDB Helm chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   └── README.md
│   └── mongo-express/                  # Mongo Express Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── README.md
└── README.md                           # This file
```

## 🔧 Management Commands

### Deployment
```bash
# Deploy complete stack
./setup-DB.sh

# Deploy individual components
./deploy-mongoDB.sh          # MongoDB only
./deploy-mongoExpress.sh     # Mongo Express only (requires MongoDB)
```

### Monitoring
```bash
# Check Helm releases
helm list

# Check pod status
kubectl get pods -l "app.kubernetes.io/name=mongodb"
kubectl get pods -l "app.kubernetes.io/name=mongo-express"

# Check services
kubectl get svc | grep mongo

# View logs
kubectl logs -l "app.kubernetes.io/name=mongodb"
kubectl logs -l "app.kubernetes.io/name=mongo-express"
```

### Cleanup
```bash
# Remove complete stack
./cleanup-DB.sh

# Remove individual components
helm uninstall mongo-express  # Remove Mongo Express
helm uninstall mongodb        # Remove MongoDB
```

## 🛠️ Configuration

### MongoDB Configuration
Edit `helm-chart/mongodb/values.yaml`:
```yaml
replicaCount: 1
auth:
  rootUsername: "username"
  rootPassword: "password"
service:
  port: 27017
```

### Mongo Express Configuration
Edit `helm-chart/mongo-express/values.yaml`:
```yaml
nodePort:
  enabled: true
  port: 30081
mongodb:
  host: "mongodb-service"
  secretName: "mongodb-secret"
```

## 🔗 Integration with Profile API

The Profile API can connect to MongoDB using:
```python
import pymongo

# Connection string
client = pymongo.MongoClient("mongodb://username:password@mongodb-service:27017/")
db = client["profile_db"]
```

## 🧪 Testing

### Test MongoDB Connection
```bash
# Get MongoDB pod name
MONGO_POD=$(kubectl get pods -l "app.kubernetes.io/name=mongodb" -o jsonpath='{.items[0].metadata.name}')

# Test connection
kubectl exec $MONGO_POD -- mongosh --eval "db.runCommand('ping').ok"
```

### Test Mongo Express
```bash
# Check if web interface is accessible
curl -s -o /dev/null -w "%{http_code}" http://localhost:30081
# Expected: 401 (authentication required)
```

## 🛡️ Security Notes

- Default credentials are for development only
- For production, change credentials in `values.yaml`
- Consider using Kubernetes secrets for credentials
- Enable authentication and authorization in MongoDB

## 📚 Additional Resources

- [MongoDB Helm Chart Documentation](./helm-chart/mongodb/README.md)
- [Mongo Express Helm Chart Documentation](./helm-chart/mongo-express/README.md)
- [MongoDB Official Documentation](https://docs.mongodb.com/)
- [Mongo Express Documentation](https://github.com/mongo-express/mongo-express)
