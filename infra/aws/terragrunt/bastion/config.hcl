locals {
  bastion_instance_type         = "t3.micro"
  ubuntu_ami_owner              = "099720109477"
  ubuntu_ami_name_pattern       = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
  ubuntu_ami_virtualization_type = "hvm"
}
