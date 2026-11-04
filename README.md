# Kubernetes Platform Lab

A hands-on Kubernetes project built around a Shopping List application. The local lab covers cluster provisioning, application access, and network troubleshooting. A separate AWS track will cover infrastructure provisioning and private EKS access.

## Choose a track

| Track | Status | What it covers |
|---|---|---|
| [Local Kubernetes](docs/local-kubernetes.md) | Available | Build a two-node cluster on Windows with Vagrant, VirtualBox, and Ansible. Choose Calico or Cilium. The Cilium walkthrough covers MetalLB, Ingress NGINX, Hubble, and NetworkPolicy. |
| AWS EKS | Planned | Provision a VPC and bastion with Terraform, then use Terragrunt to deploy EKS with a private API endpoint and worker nodes in private subnets. This track will require an AWS account. VirtualBox will be optional. |

The local lab defaults to **2 vCPUs per VM** and **5,120 MB of guest RAM total**: 3,072 MB for the control plane and 2,048 MB for the worker. See the [local guide](docs/local-kubernetes.md#vm-resources-and-configuration) for setup instructions and resource overrides.

## What I verified

- **Application access from Windows.** A request to `shopping.lab/api/items` returned the shopping list through MetalLB and Ingress NGINX.
- **HTTP 504 troubleshooting.** NGINX logged an upstream connection timeout. Hubble showed Cilium dropping the ingress controller's TCP SYN to the frontend with `Policy denied`. A targeted NetworkPolicy restored access on TCP port 80 while preserving default-deny ingress.
- **Cross-node traffic.** Hubble identified the communicating pods. A packet capture on the node interface showed their ICMP requests and replies encapsulated in VXLAN over UDP port 8472.

## Design trade-offs

**Local lab.** Two Ubuntu VMs make it possible to inspect traffic between Kubernetes nodes from a Windows workstation. Vagrant makes the setup repeatable, at the cost of additional RAM and disk space.

**AWS lab.** The planned EKS environment uses a public bastion for administrative access and private worker subnets. A single managed worker and short test sessions keep the lab within a personal budget. This is enough to validate private access and deploy the application. Workload failover requires a separate multi-worker test.
