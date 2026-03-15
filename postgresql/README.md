# PostgreSQL Local Stack

PostgreSQL + pgAdmin deployment for local k3d development (Phase 3 of DB migration).

## Quick Start

```bash
# Deploy PostgreSQL + pgAdmin
./setup-DB.sh

# Cleanup
./cleanup-DB.sh
```

Or deploy from the local_stack root:

```bash
./setup-service.sh -postgresql
```

## Access

| Service    | URL / Address                                              |
|------------|------------------------------------------------------------|
| pgAdmin    | http://localhost:30084                                     |
| PostgreSQL | postgresql-service.local-stack.svc.cluster.local:5432     |

## Credentials

**pgAdmin login:**
- Email: `admin@local.dev`
- Password: `password`

**PostgreSQL:**
- Username: `username`
- Password: `password`
- Database: `AISecurityMgmtServiceDB`

## Connect pgAdmin to PostgreSQL

After opening http://localhost:30084, add a new server:
- Host: `postgresql-service`
- Port: `5432`
- Database: `AISecurityMgmtServiceDB`
- Username: `username`
- Password: `password`

## Useful Commands

```bash
# psql shell
kubectl exec -it $(kubectl get pods -l "app.kubernetes.io/name=postgresql" -n local-stack -o jsonpath='{.items[0].metadata.name}') \
    -n local-stack -- psql -U username -d AISecurityMgmtServiceDB

# Check Helm releases
helm list -n local-stack

# PostgreSQL logs
kubectl logs -l "app.kubernetes.io/name=postgresql" -n local-stack

# pgAdmin logs
kubectl logs -l "app.kubernetes.io/name=pgadmin" -n local-stack
```

## Notes

- PostgreSQL is ClusterIP only (no external NodePort) — access via `kubectl exec` or through pgAdmin
- mgmt-service defaults to MongoDB (`DB_TYPE=mongodb`); switch to `DB_TYPE=postgresql` in `pkg/deployment.yaml` to test PostgreSQL connectors (Phase 4)
- MongoDB and PostgreSQL coexist in k3d during migration
