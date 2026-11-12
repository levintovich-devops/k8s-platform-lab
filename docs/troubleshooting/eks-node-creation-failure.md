# EKS NodeCreationFailure — troubleshooting

## 2026-11-11: NAT Gateway experiment and CNI initialization

**Environment:** AWS `eu-north-1`; EKS cluster `aws-lab-eks`; Amazon Linux 2023 managed worker nodes (`t3.small`) in private subnets.

### Previous observation

An earlier EKS deployment reported `NodeCreationFailure: Instances failed to join the kubernetes cluster`. The EC2 system log showed SSM endpoint connection failures. This did **not** establish the definitive cause of node registration failure.

### Experiment

A public NAT Gateway with an Elastic IP was deployed in the existing public subnet. A default IPv4 route (`0.0.0.0/0`) through NAT was added to the shared private route table. EKS was then deployed again.

### Observed facts

- The EC2 worker system log showed `nodeadm` loading the EKS configuration and starting `containerd` and `kubelet` successfully:
  ```text
  Daemon is running {"name": "containerd"}
  Daemon is running {"name": "kubelet"}
  done! {"duration": 0.808911056}
  ```
- While the managed node group was provisioning, the following error was reported:
  ```text
  container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
  ```
- The AWS Console AI assistant identified a possible **EKS CNI Plugin Initialization Issue**, affecting both nodes, and noted the limited pod density of `t3.small`.
- The EKS Console **Add-ons** tab showed no managed add-ons at inspection time.
- The user decided to destroy EKS and NAT promptly to limit costs. A final node group state or successful `kubectl get nodes` result was not supplied.

### Interpretation — not yet a confirmed root cause

- Successful `nodeadm`/runtime/kubelet startup does not prove the nodes registered with the EKS API.
- `NetworkPluginNotReady` establishes that the CNI plugin was not initialized at the time of the error, but not *why*.
- An empty EKS managed Add-ons list does not prove that a self-managed `aws-node` DaemonSet is absent.
- Improved initialization logs after NAT deployment do not prove NAT was the sole cause of the earlier failure.

### Next investigation

Before recreating paid resources, inspect Terraform/Terragrunt EKS add-on configuration, the VPC CNI installation method, and ordering relative to managed node group creation. During the next experiment, inspect node group health and `aws-node` status using an accessible management path.

Keep EKS and NAT short-lived; destroy EKS before NAT.
