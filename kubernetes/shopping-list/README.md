# Shopping List Kubernetes Lab

Deploy the Shopping List application from Linux using published Docker Hub images. No Docker build, image export/import, SCP, or PowerShell is required.

Components in namespace `network-lab`:
- Nginx frontend: `levintovich/shopping-list-frontend:latest`
- Go API backend: `levintovich/shopping-list-backend:latest`
- PostgreSQL: `postgres:16-alpine`

The frontend proxies same-origin `/api/` requests to the backend Service. The backend connects to the `postgres` Service using Kubernetes DNS.

## Prerequisites

A running Kubernetes cluster with CNI, CoreDNS, `kubectl` access, and worker-node connectivity to Docker Hub. The frontend and backend manifests already use `imagePullPolicy: Always`, so Kubernetes downloads their images automatically.

Run the following commands from the Linux repository root:

```bash
cd /workspace/k8s-platform-lab
```

## Database credentials

Create a local ignored credentials file, then edit its password:

```bash
mkdir -p .local
cat > .local/shopping-list-postgres.env <<'EOF'
POSTGRES_USER=shopping
POSTGRES_PASSWORD=replace-with-a-strong-password
POSTGRES_DB=shopping
EOF
vi .local/shopping-list-postgres.env
```

Create the namespace and Secret:

```bash
kubectl apply -f kubernetes/shopping-list/namespace.yaml
kubectl -n network-lab create secret generic postgres-credentials \
  --from-env-file=.local/shopping-list-postgres.env \
  --dry-run=client -o yaml | kubectl apply -f -
```

The `.local/` directory is Git-ignored. Do not commit credentials. Kubernetes Secrets are not encrypted in etcd by default.

## PostgreSQL: local cluster versus EKS

**The existing `postgres.yaml` is local-cluster-only.** It selects a node with hostname `worker` and uses a static `hostPath` volume. EKS worker nodes have different hostnames, and node-local `hostPath` is not suitable for durable EKS storage.

For EKS, first replace the local-only node selector and volume with EKS-compatible storage, such as an EBS CSI-backed PersistentVolumeClaim and StorageClass. Do not apply the existing PostgreSQL manifest unchanged on EKS.

## Deploy

On the local cluster, after creating the Secret:

```bash
kubectl apply -f kubernetes/shopping-list/postgres.yaml
kubectl apply -f kubernetes/shopping-list/backend.yaml
kubectl apply -f kubernetes/shopping-list/frontend.yaml
```

On EKS, deploy PostgreSQL using the EKS-compatible manifest first, then apply `backend.yaml` and `frontend.yaml` above.

Check rollout and resources:

```bash
kubectl -n network-lab rollout status deployment/postgres --timeout=5m
kubectl -n network-lab rollout status deployment/backend --timeout=5m
kubectl -n network-lab rollout status deployment/frontend --timeout=5m
kubectl -n network-lab get pods,svc,pvc -o wide
```

If a Pod fails, inspect its events:

```bash
kubectl -n network-lab describe pods
```

## Access and end-to-end test (no port-forward)

The frontend Service is `ClusterIP`. The repository does not include a Shopping List Ingress manifest. Configure an Ingress controller and an Ingress routing your hostname to `network-lab/frontend` port `80` before testing from outside the cluster. For a private EKS cluster, ensure your client has a network path to the Ingress endpoint.

Set the URL to the actual reachable hostname (the example below is for the local lab):

```bash
APP_URL=http://shopping.lab
curl -fsS "$APP_URL/healthz"
curl -fsS -X POST "$APP_URL/api/items" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Apples","quantity":3}'
curl -fsS "$APP_URL/api/items"
```

Use the returned item ID to delete it:

```bash
curl -fsS -X DELETE "$APP_URL/api/items/REPLACE_WITH_ID"
curl -fsS "$APP_URL/api/items"
```

Check persisted rows in PostgreSQL:

```bash
kubectl -n network-lab exec deployment/postgres -- sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, name, quantity, created_at FROM shopping_items ORDER BY id;"'
```

## Cleanup and storage limitations

The local PostgreSQL PersistentVolume uses a 2 GiB `hostPath` at `/var/lib/k8s-platform-lab/shopping-list/postgres` with reclaim policy `Retain`. It is node-local, not replicated or backed up.

To remove workloads without intentionally removing retained data:

```bash
kubectl delete -f kubernetes/shopping-list/frontend.yaml
kubectl delete -f kubernetes/shopping-list/backend.yaml
kubectl delete -f kubernetes/shopping-list/postgres.yaml
```

Leave the `network-lab` namespace if other workloads use it. Remove the local credentials file when no longer needed.
