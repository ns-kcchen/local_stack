================================================================================
  local_stack 操作指令
================================================================================

【主要腳本】（從 local_stack/ 目錄執行）

  ./setup-k3d.sh                  建立 k3d cluster（第一次使用）
  ./setup-service.sh              部署所有服務（MongoDB + PostgreSQL + Mock RIS + Mock Push）
  ./setup-service.sh -mongodb     僅部署 MongoDB + Mongo Express
  ./setup-service.sh -mock-ris    僅部署 Mock RIS
  ./setup-service.sh -mock-push   僅部署 Mock Push
  ./setup-service.sh -pgsql       僅部署 PostgreSQL + pgAdmin（Phase 3）
  ./reload.sh                     重新 build + deploy mgmt-service
  ./clean-k3d.sh                  刪除整個 k3d cluster

【子目錄腳本】（個別 DB 操作）

  mongoDB/setup-DB.sh             部署 MongoDB + Mongo Express
  mongoDB/cleanup-DB.sh           清除 MongoDB stack
  postgresql/setup-DB.sh          部署 PostgreSQL + pgAdmin
  postgresql/cleanup-DB.sh        清除 PostgreSQL stack

【服務端口】

  30080   mgmt-service API    http://localhost:30080
  30080   mgmt-service Docs   http://localhost:30080/docs
  30080   mgmt-service Health http://localhost:30080/healthcheck
  30081   Mongo Express       http://localhost:30081
  30082   Mock RIS            http://localhost:30082
  30083   Mock Push           http://localhost:30083
  30084   pgAdmin             http://localhost:30084
  ---     PostgreSQL          postgresql-service:5432  (ClusterIP，cluster 內存取)
  ---     MongoDB             mongodb-service:27017    (ClusterIP，cluster 內存取)

【認證資訊】

  MongoDB / Mongo Express
    username: username
    password: password

  PostgreSQL
    username: admin
    password: p@ssw0rd
    database: AISecurityMgmtServiceDB

  pgAdmin
    email:    admin@local.dev
    password: password

  pgAdmin 新增 PostgreSQL Server（常規 tab）：
    名稱：postgresql-service

  pgAdmin 新增 PostgreSQL Server（連接 tab）：
    Host:     postgresql-service
    Port:     5432
    Database: AISecurityMgmtServiceDB
    Username: admin
    Password: p@ssw0rd

【常用 kubectl 指令】

  kubectl get all -n local-stack
  kubectl get pods -n local-stack
  helm list -n local-stack

  # Logs
  kubectl logs -l app=aisecurity-mgmt-service -n local-stack
  kubectl logs -l app.kubernetes.io/name=mongodb -n local-stack
  kubectl logs -l app.kubernetes.io/name=postgresql -n local-stack
  kubectl logs -l app=mock-ris -n local-stack
  kubectl logs -l app=mock-push -n local-stack

  # 重啟 mgmt-service
  kubectl rollout restart deployment/aisecurity-mgmt-service -n local-stack

  # psql shell
  kubectl exec -it $(kubectl get pods -l app.kubernetes.io/name=postgresql \
      -n local-stack -o jsonpath='{.items[0].metadata.name}') \
      -n local-stack -- psql -U username -d AISecurityMgmtServiceDB

【典型初始化流程】

  1. ./setup-k3d.sh
  2. ./setup-service.sh
  3. ./reload.sh

  （選用）部署 PostgreSQL：
  4. ./setup-service.sh -pgsql

================================================================================
