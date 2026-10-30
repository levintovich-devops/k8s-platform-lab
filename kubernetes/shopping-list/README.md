# Shopping List Kubernetes Lab

This lab runs a browser UI served by Nginx, a Go REST API, and PostgreSQL 16 in the `network-lab` namespace. The browser sends same-origin `/api/` requests to Nginx; Nginx proxies them to the `backend` Service, and the API connects to the `postgres` Service using Kubernetes DNS. No NetworkPolicies are included.

## Requirements and image distribution

- A working Kubernetes cluster with a CNI installed, cluster DNS working, and `kubectl` access. This repository's initial cluster phase has no CNI, so deploy only after installing the networking component for your cluster.
- Docker Desktop on Windows with Linux-container support, or another builder that can build Linux/amd64 container images.
- Linux Kubernetes nodes running containerd, or an image registry reachable by every node.

These manifests use `imagePullPolicy: Never` and locally tagged images. They do not assume a registry. Build the images on Windows, export them, and import each into containerd on **both** Kubernetes nodes. If you have configured a registry instead, push the images there and change the image references and pull policy in the manifests.

From the repository root in PowerShell:

```powershell
docker build --platform linux/amd64 -t shopping-list-frontend:local .\apps\shopping-list\frontend
docker build --platform linux/amd64 -t shopping-list-backend:local .\apps\shopping-list\backend
docker save -o .\shopping-list-frontend.tar shopping-list-frontend:local
docker save -o .\shopping-list-backend.tar shopping-list-backend:local
```

Copy both archives to each Linux node using your established SSH/SCP access. On each node, import them into containerd's Kubernetes namespace:

```sh
sudo ctr -n k8s.io images import shopping-list-frontend.tar
sudo ctr -n k8s.io images import shopping-list-backend.tar
```

Delete the exported archives from the nodes and Windows host after import if they are no longer needed. Alternatively, configure a registry and push both images there. The image tag and architecture must match what the manifests reference and what the nodes can run.

## Create local credentials

Create the ignored `.local` folder and the local environment file from PowerShell. Choose your own strong password; do not commit this file.

```powershell
New-Item -ItemType Directory -Force .local | Out-Null
@'
POSTGRES_USER=shopping
POSTGRES_PASSWORD=replace-with-a-local-password
POSTGRES_DB=shopping
'@ | Set-Content -NoNewline .local\shopping-list-postgres.env
```

Edit `.local\shopping-list-postgres.env` and replace the example password. `.local/` is Git-ignored. Create/update the Kubernetes Secret directly from that file; no plaintext Secret manifest is written:

```powershell
kubectl create namespace network-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic postgres-credentials `
  --namespace network-lab `
  --from-env-file=.local\shopping-list-postgres.env `
  --dry-run=client -o yaml | kubectl apply -f -
```

Kubernetes Secrets are base64-encoded, not encrypted by default in etcd. Use only a lab cluster with appropriately restricted access; enable encryption at rest and access controls for anything beyond a disposable local lab.

## Deploy

From the repository root in PowerShell, after images are imported on every node and the Secret exists:

```powershell
kubectl apply -f .\kubernetes\shopping-list\namespace.yaml
kubectl apply -f .\kubernetes\shopping-list\postgres.yaml
kubectl apply -f .\kubernetes\shopping-list\backend.yaml
kubectl apply -f .\kubernetes\shopping-list\frontend.yaml
kubectl -n network-lab rollout status deployment/postgres --timeout=5m
kubectl -n network-lab rollout status deployment/backend --timeout=5m
kubectl -n network-lab rollout status deployment/frontend --timeout=5m
```

The Postgres deployment will wait for its Secret and persistent volume claim. If a password changes after initial database initialization, update the Secret and separately change the database role password; the official PostgreSQL image uses initialization variables only for an empty data directory.

Access the UI from Windows with a port-forward in one PowerShell window:

```powershell
kubectl -n network-lab port-forward service/frontend 8080:80
```

Open `http://localhost:8080` in a browser. This lab intentionally does not create an Ingress resource; add an Ingress controller and route separately when that portion of the lab is ready.

## Verify end to end

With the port-forward running, use a second PowerShell window to check the proxy path, create an item, and fetch the saved item:

```powershell
Invoke-WebRequest http://localhost:8080/healthz
$created = Invoke-RestMethod -Method Post `
  -Uri http://localhost:8080/api/items `
  -ContentType 'application/json' `
  -Body '{"name":"Apples","quantity":3}'
$created
Invoke-RestMethod http://localhost:8080/api/items
```

Check the persisted row using `psql` in the database pod:

```powershell
$pod = kubectl -n network-lab get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}'
kubectl -n network-lab exec $pod -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, name, quantity, created_at FROM shopping_items ORDER BY id;"'
```

Delete the item and confirm it is gone:

```powershell
Invoke-WebRequest -Method Delete "http://localhost:8080/api/items/$($created.id)" -UseBasicParsing
Invoke-RestMethod http://localhost:8080/api/items
```

You can also inspect the internal service endpoints without relying on Pod IPs:

```powershell
kubectl -n network-lab get services,pods,pvc
```

## Storage and cleanup limitations

The static 2 GiB PersistentVolume uses `hostPath` at `/var/lib/k8s-platform-lab/shopping-list/postgres`. Data survives pod recreation on the same node, but this is not replicated or backed up. Kubernetes may schedule the pod on another node after rescheduling; `hostPath` data is node-local, so the data will not follow. Do not treat it as production storage. The PV reclaim policy is `Retain`; deleting the claim does not erase the node's data.

To remove the application without removing the retained database data:

```powershell
kubectl delete -f .\kubernetes\shopping-list\frontend.yaml
kubectl delete -f .\kubernetes\shopping-list\backend.yaml
kubectl delete -f .\kubernetes\shopping-list\postgres.yaml
```

The namespace and local credentials file are intentionally left in place. Remove `.local\shopping-list-postgres.env` yourself when no longer needed. Do not delete the `network-lab` namespace if other lab workloads use it.
