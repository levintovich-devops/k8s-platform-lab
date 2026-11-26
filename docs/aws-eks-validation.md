# AWS EKS — Shopping List Infrastructure Validation Runbook

This runbook records the infrastructure checks performed successfully on **2026-11-26** in the `aws-lab-eks` cluster (`eu-north-1`). It is intended to be executed after each fresh EKS deployment, from the **Bastion** with working `kubectl` access. Run each command in order and verify its output before continuing.

**Scope:** Kubernetes Services, internal HTTP routing, PostgreSQL SQL connectivity, EBS CSI persistent storage, and recovery after PostgreSQL Pod recreation. This is **platform validation**, not application feature QA. External Ingress / Load Balancer access was **not configured or tested**.

## Architecture under test

```text
Bastion (kubectl)
  └─ exec → curl-test Pod (namespace network-lab)
                │
                └─ frontend Service :80
                      └─ Nginx frontend Pod
                            └─ /api/* reverse proxy → backend Service :8080
                                  └─ Go backend Pod
                                        └─ postgres Service :5432
                                              └─ PostgreSQL Pod
                                                    └─ PVC postgres-data
                                                          └─ AWS EBS gp3 via ebs.csi.aws.com
```

The Nginx reverse proxy is baked into the frontend image using `apps/shopping-list/frontend/nginx.conf`; there is **no application Nginx ConfigMap**. `/api/` proxies to `http://backend:8080`. The Go backend uses `shopping_items` (not `items`). PostgreSQL credentials come from the `postgres-credentials` Secret; **do not assume a `postgres` database role exists**.

## Prerequisites

- EKS cluster and worker nodes ready; Bastion `kubectl` context points to the intended cluster.
- EBS CSI driver installed with working IAM permissions; `network-lab` namespace and `postgres-credentials` Secret created.
- EKS application deployed using `kubernetes/shopping-list/postgres-eks.yaml`, `backend.yaml`, and `frontend.yaml` (see [deployment guide](../kubernetes/shopping-list/README.md)).
- Run from Bastion. The `curl-test` Pod is a diagnostic tool and must be removed during cleanup.
- Never commit or print PostgreSQL passwords.

## 1. Verify deployed workloads and Services

```bash
kubectl -n network-lab get pods -o wide
```

**Expected:** frontend, backend, and postgres Pods are `Running` and `Ready`. Note the `NODE` and `IP` columns; they vary with each deployment.

```bash
kubectl -n network-lab get svc
```

**Expected:** `frontend:80`, `backend:8080`, `postgres:5432` are ClusterIP Services.

```bash
kubectl -n network-lab get endpointslices
```

**Expected:** each Service has at least one ready backend endpoint. Pod IPs and EndpointSlice names are dynamic.

## 2. Create the internal HTTP test Pod

```bash
kubectl -n network-lab run curl-test --image=curlimages/curl -- sleep 3600
```

```bash
kubectl -n network-lab get pod curl-test
```

**Expected:** `1/1 Running`. If it is not ready, wait and retry. The `sleep 3600` Pod may terminate after one hour; recreate it if necessary.

## 3. Backend Service and PostgreSQL integration

```bash
kubectl -n network-lab exec curl-test -- curl -i http://backend:8080/api/items
```

**Expected:** `HTTP/1.1 200 OK` and a JSON array (`[]` is valid for an empty database). This validates Pod DNS resolution, backend Service routing, API availability, and the backend's ability to read PostgreSQL.

Create one known validation record only if it does not already exist:

```bash
kubectl -n network-lab exec curl-test -- curl -i -X POST http://backend:8080/api/items -H "Content-Type: application/json" -d '{"name":"Milk","quantity":1}'
```

**Expected:** `201 Created`. Both `name` and `quantity` are required. Do not repeatedly create this record on the same persistent database.

```bash
kubectl -n network-lab exec curl-test -- curl -i http://backend:8080/api/items
```

**Expected:** `200 OK` and the newly inserted record. API DELETE was deliberately not part of this infrastructure validation.

## 4. Frontend and full internal request path

```bash
kubectl -n network-lab exec curl-test -- curl -i http://frontend
```

**Expected:** `200 OK` and HTML from Nginx. This alone **does not** prove backend connectivity.

```bash
kubectl -n network-lab exec curl-test -- curl -i http://frontend/api/items
```

**Expected:** `200 OK` and the known `Milk` record. This validates the internal path **test Pod → frontend Service → Nginx reverse proxy → backend Service → Go API → PostgreSQL → response**. It does not test external Ingress or a real browser.

## 5. PostgreSQL readiness and SQL

Use `deployment/postgres` rather than a generated Pod name, which changes on recreation.

```bash
kubectl -n network-lab exec deployment/postgres -- pg_isready
```

**Expected:** `accepting connections`. This does not prove SQL authentication.

```bash
kubectl -n network-lab exec deployment/postgres -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT current_database(), current_user;"'
```

**Expected:** `shopping | shopping` for the currently configured Secret.

```bash
kubectl -n network-lab exec deployment/postgres -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM shopping_items;"'
```

**Expected:** the validation record is present. The table is **shopping_items**; querying `items` returns `relation does not exist`. The role `postgres` is not provisioned in the verified instance; use `$POSTGRES_USER`.

## 6. EBS PersistentVolume and topology

```bash
kubectl -n network-lab get pvc postgres-data
```

**Expected:** `Bound`, `2Gi`, `RWO`, StorageClass `shopping-list-ebs-gp3`. Record the dynamically generated PV name in the `VOLUME` column.

```bash
kubectl get pv
```

**Expected:** the PV named by `postgres-data` is `Bound`.

```bash
kubectl get pv <PV_NAME> -o yaml
```

Replace `<PV_NAME>` with the name shown by the PVC output. Inspect `spec.csi.driver`, `spec.csi.volumeHandle`, and `spec.nodeAffinity`.

**Verified on 2026-11-26:** `ebs.csi.aws.com`; EBS Volume `vol-070b6b42e77f1ed68`; AZ `eu-north-1a`. These are **historical example values, not reusable IDs**. EBS is AZ-scoped and is not a multi-AZ replicated database.

## 7. Pod recreation and data persistence

First, ensure Section 5 shows the expected SQL record. Then deliberately recreate **only the PostgreSQL Pod**:

```bash
kubectl -n network-lab delete pod -l app=postgres
```

**Expected:** the Deployment recreates its Pod. This command does **not** delete the PVC. Use only in this disposable lab; expect a short database interruption.

```bash
kubectl -n network-lab rollout status deployment/postgres --timeout=5m
```

**Expected:** rollout successfully completed.

```bash
kubectl -n network-lab get pods -o wide
```

**Expected:** a new PostgreSQL Pod name, `1/1 Running`.

```bash
kubectl -n network-lab exec deployment/postgres -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM shopping_items;"'
```

**Expected:** the original record remains unchanged.

```bash
kubectl -n network-lab exec curl-test -- curl -i http://frontend/api/items
```

**Expected:** `200 OK` and the same record, proving the application path recovers after PostgreSQL Pod replacement.

**Verified outcome:** PostgreSQL was recreated, the SQL record survived, and the frontend-proxied API returned the saved data.

## 8. Not yet validated

- External Ingress / public or private Load Balancer access: **no Ingress existed** in the EKS cluster during this session.
- Browser rendering and browser-initiated requests.
- Cross-node packet tracing / CNI-level diagnostics (Pod placement was observed, but no packet-level trace was completed).
- Database backups, AZ failover, or resilience to deleting the PVC.
- Full automated Terragrunt add-on provisioning.

Do not describe any of these as completed.

## 9. Cleanup before Terragrunt destroy

**Warning:** the EKS StorageClass uses `reclaimPolicy: Delete`. Deleting the PVC normally causes the associated AWS EBS volume and its data to be deleted. Preserve data or take a backup first if needed. For this disposable lab, remove the diagnostic Pod and application resources before destroying the cluster.

```bash
kubectl -n network-lab delete pod curl-test --ignore-not-found
```

```bash
kubectl -n network-lab delete -f kubernetes/shopping-list/frontend.yaml
```

```bash
kubectl -n network-lab delete -f kubernetes/shopping-list/backend.yaml
```

```bash
kubectl -n network-lab delete -f kubernetes/shopping-list/postgres-eks.yaml
```

**Caution:** the last manifest also contains the StorageClass, PVC, PostgreSQL Deployment, and Service. Ensure the PVC is deleted and the EBS volume has actually been removed before destroying the EKS/VPC infrastructure. Confirm any LoadBalancer Services and other billable resources are cleaned up. Destroy Terraform/Terragrunt-managed infrastructure only from the correct live configuration and in dependency-safe order. This runbook does not prescribe a `terragrunt destroy` command without inspecting the current stack.

## 10. Future automation

After teardown, create a dedicated Terragrunt `addons` module via Copilot. First inventory the **two existing add-ons**, their IAM / Pod Identity dependencies, current manually applied settings, and lifecycle ordering. Then make provisioning repeatable and document the actual validation results. This work is **planned**, not completed.

## Validation evidence (2026-11-26)

| Check | Result |
|---|---|
| Backend GET via ClusterIP Service | PASS — HTTP 200 |
| Backend POST of Milk, quantity 1 | PASS — HTTP 201 |
| Backend GET after insert | PASS — record returned |
| Frontend Service GET | PASS — HTML returned |
| Frontend /api/items reverse proxy | PASS — record returned |
| PostgreSQL pg_isready | PASS — accepting connections |
| PostgreSQL SQL authentication | PASS — database shopping, user shopping |
| PostgreSQL SELECT shopping_items | PASS — Milk, id 1, quantity 1 |
| PVC and EBS CSI metadata | PASS — Bound, gp3, ebs.csi.aws.com |
| PostgreSQL Pod recreation | PASS — replacement Running |
| SQL data persistence after recreation | PASS — record preserved |
| Frontend /api/items after recreation | PASS — record returned |
| Ingress / Load Balancer | NOT TESTED — not configured |

