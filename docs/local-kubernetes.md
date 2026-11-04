# Local Kubernetes on Windows

A reproducible two-node Kubernetes lab on Windows with Vagrant, VirtualBox, Ansible, and kubeadm. The Shopping List application provides a real workload for testing ingress, network policy, and cross-node traffic.

- **Cluster provisioning:** Ansible configures containerd and bootstraps the control plane and worker. Select Calico or Cilium with `CNI_PLUGIN`.
- **Application access:** MetalLB and Ingress NGINX expose Shopping List and Hubble UI in the Cilium lab. A request from Windows to `shopping.lab/api/items` returned the shopping list.
- **Network policy troubleshooting:** An HTTP 504 led to an NGINX upstream connection timeout. Hubble showed Cilium dropping the controller's TCP SYN to the frontend with `Policy denied`. A targeted NetworkPolicy allowed TCP/80 from the controller and restored access.
- **Cross-node networking:** Hubble identified the communicating pods. A packet capture on the VM interface showed the ICMP requests and replies encapsulated in VXLAN over UDP/8472.

## Architecture

- `control-plane`: Ubuntu 22.04 LTS, containerd, kubeadm control plane.
- `worker`: Ubuntu 22.04 LTS, containerd, joined to the control plane.
- Each VM receives VirtualBox's default NAT interface for outbound internet and a configurable host-only address for node-to-node and host-to-API access.
- The project directory is synced to `/vagrant` in both guests. Vagrant starts the worker first, then starts the control-plane VM, copies the worker's Vagrant-managed SSH private key into the control-plane VM, and runs one Ansible orchestration playbook there.
- Ansible configures the control plane locally and configures the worker over SSH using its Vagrant `vagrant` account, host-only IP, and Vagrant-managed private key. SSH host key checking remains enabled; only the worker's first-seen key is accepted with OpenSSH `accept-new`.
- The control-plane play generates a fresh kubeadm join command in Ansible memory. The worker play uses that registered value to join; the command is neither written to the project folder nor printed in task output. The control-plane play copies a host-accessible kubeconfig into `.vagrant`.
- Kubernetes packages are installed from the official `pkgs.k8s.io` repository and held at the exact version in `ansible/group_vars/all.yml`.
- The default Pod CIDR is `10.244.0.0/16`. It is configured during bootstrap.

## Repository layout

| Path | Contents |
|---|---|
| `Vagrantfile`, `ansible/` | VM provisioning, Kubernetes bootstrap, and Calico and Cilium roles |
| [`apps/shopping-list/`](../apps/shopping-list/) | Shopping List source code |
| [`kubernetes/shopping-list/`](../kubernetes/shopping-list/) | Workload manifests, services, storage, and NetworkPolicies |
| [`kubernetes/metallb/`](../kubernetes/metallb/) | MetalLB manifests and lab IP pool |
| [`kubernetes/ingress-nginx/`](../kubernetes/ingress-nginx/) | Ingress controller configuration and routes for Shopping List and Hubble UI |
| `labs/` | Networking experiments |

## Prerequisites

- Windows 10/11.
- Oracle VirtualBox and Vagrant installed on Windows.
- Hardware virtualization enabled in firmware.
- Network access from the VMs to Ubuntu and Kubernetes package repositories.

Ansible is installed automatically only on the control-plane VM by Vagrant's `ansible_local` provisioner. It is not installed on Windows or the worker. `kubectl` on Windows is optional because verification can be run inside the control-plane VM.

The box `ubuntu/jammy64` is pinned to version `20241002.0.0`. The Kubernetes package is pinned to `1.35.0-1.1` from the stable `v1.35` repository. Update both pins deliberately when refreshing the lab.

## VM resources and configuration

Defaults are 2 vCPUs and 4096 MB RAM per VM (4 vCPUs and 8 GB RAM total). The host needs additional memory for Windows and VirtualBox. Increase resources if running other workloads.

Set optional environment variables in PowerShell before running Vagrant:

| Variable | Default | Description |
|---|---:|---|
| `CONTROL_PLANE_IP` | `192.168.56.10` | Control-plane host-only IPv4 address |
| `WORKER_IP` | `192.168.56.11` | Worker host-only IPv4 address |
| `CONTROL_PLANE_CPUS` | `2` | Control-plane vCPUs |
| `CONTROL_PLANE_MEMORY_MB` | `4096` | Control-plane RAM in MB |
| `WORKER_CPUS` | `2` | Worker vCPUs |
| `WORKER_MEMORY_MB` | `4096` | Worker RAM in MB |
| `CNI_PLUGIN` | `calico` | CNI installed by Ansible: `calico` or `cilium` |
| `POD_CIDR` | `10.244.0.0/16` | Cluster Pod CIDR passed to kubeadm |

Confirm the chosen host-only addresses belong to a VirtualBox host-only network and are not in use. Vagrant supplies the NAT interfaces automatically.

## Start and stop

For a fresh Cilium lab, set `$env:CNI_PLUGIN = "cilium"` in PowerShell before running `vagrant up`. Choose the CNI at bootstrap. An existing cluster requires a separate migration procedure to switch CNIs.

Run these commands from PowerShell in the repository directory:

```powershell
vagrant up
vagrant status
```

The worker VM is defined first and brought up before the control-plane VM. Once the worker exists, Vagrant copies its generated private key into the control-plane VM and runs the single `ansible/site.yml` playbook there. Ansible configures the control plane locally, initializes it only when not already initialized, then connects to the worker over SSH and joins it to the cluster. Re-run provisioning with:

```powershell
vagrant provision
```

Shut down without deleting the VMs:

```powershell
vagrant halt
```

Delete both VMs and their disks:

```powershell
vagrant destroy
```

Destroying the VMs removes the cluster state. A subsequent `vagrant up` creates a fresh cluster.

## Verify the cluster

The host-accessible kubeconfig is written to `.vagrant\kubeconfig` (ignored by Git). If `kubectl` is installed on Windows, use:

```powershell
kubectl --kubeconfig .vagrant\kubeconfig get nodes -o wide
kubectl --kubeconfig .vagrant\kubeconfig get pods -A
```

Or verify from the control-plane VM without installing kubectl on Windows:

```powershell
vagrant ssh control-plane -c "kubectl get nodes -o wide"
vagrant ssh control-plane -c "kubectl get pods -A"
```

## Application and ingress

Deploy the application using the [Shopping List instructions](../kubernetes/shopping-list/README.md). The lab also provides [MetalLB](../kubernetes/metallb/) and [Ingress NGINX](../kubernetes/ingress-nginx/) manifests. Apply the MetalLB IP pool after its CRDs are available. The Ingress Kustomization includes the Hubble route. Apply `shopping-ingress.yaml` and the [controller-to-frontend policy](../kubernetes/shopping-list/network-policies/allow-ingress-nginx-to-frontend.yaml) separately.

For the verified Windows setup, map `hubble.lab` and `shopping.lab` to `192.168.56.20` in the Windows hosts file. Test the API with `curl.exe -i http://shopping.lab/api/items`.

## Troubleshooting and recovery

- **Ansible provisioning fails:** inspect Vagrant's output and run `vagrant provision`; Ansible is installed on the control-plane VM by the local provisioner. The worker SSH private key is copied from Vagrant's local machine state and is not stored in Git.
- **Host-only network conflicts:** choose unused addresses in the VirtualBox host-only subnet via `CONTROL_PLANE_IP` and `WORKER_IP`.
- **Kubernetes packages cannot be found:** verify VM internet access and the `pkgs.k8s.io` repository; confirm that the pinned version in `ansible/group_vars/all.yml` exists for its configured stable minor repository.
- **Provisioning fails:** inspect the Vagrant output, then run `vagrant provision`. The initialization and join tasks detect existing cluster configuration and do not automatically reset a node.
- **Control plane or worker state is irrecoverably inconsistent:** inspect the affected VM with `vagrant ssh <machine>`, save any data you need, then use `vagrant destroy <machine>` followed by `vagrant up <machine>` to recreate it. Recreating the control plane also requires recreating the worker so it can join the new cluster. No playbook runs `kubeadm reset`.
- **Recreating a worker later:** run `vagrant up worker`, then `vagrant provision control-plane` so Vagrant refreshes the copied worker key and Ansible generates a fresh join token. If the worker was recreated with a new SSH host key, remove the old worker IP entry from `/home/vagrant/.ssh/known_hosts` on the control-plane VM before provisioning; host key checking intentionally remains enabled.
- **Host kubeconfig is stale or unavailable:** re-run `vagrant provision control-plane` to copy the current admin configuration into the shared `.vagrant` directory. The file grants cluster-admin access; keep it private and do not commit it.
 
## Design trade-offs

Vagrant and VirtualBox make the two Ubuntu nodes reproducible on a Windows workstation. Separate VMs let the lab exercise real traffic between nodes and inspect VXLAN on the host-only interface. This costs more RAM and disk space than a container-based cluster. The default lab allocates 8 GB of guest RAM across the two nodes. Halt the VMs when they are idle to free host resources and preserve the cluster disks.
