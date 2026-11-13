# EKS access

This unit connects the independent SSM-managed Bastion to the private EKS API.
It reads the Bastion and EKS outputs from their existing remote states and
manages only the Bastion's cluster-scoped `eks:DescribeCluster` policy, its EKS
access entry and cluster-admin policy association, and the HTTPS ingress rule
from the Bastion security group to the EKS cluster security group.

The ingress rule targets the AWS-managed primary cluster security group
reported by the EKS module's `cluster_primary_security_group_id` output. AWS
associates this group with the control-plane network interfaces; the EKS unit
retains its existing `cluster_security_group_id` remote-state output name for
compatibility. The rule permits only TCP/443 from the Bastion security group.

The unit does not create or modify the Bastion, EKS cluster, VPC, subnets, or
node group. It has a separate S3 state at `eks-access/terraform.tfstate`.

The Bastion uses its EC2 instance profile credentials. Do not configure static
AWS access keys on the instance. After opening an SSM session, verify the
instance role and run the `update_kubeconfig_command` value from the EKS
outputs, which supplies the configured region and cluster name:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region <configured-region> --name <configured-cluster-name>
kubectl auth can-i '*' '*'
kubectl get nodes -o wide
```
