data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ubuntu_ami_owner]

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = [var.ubuntu_ami_virtualization_type]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  tags = {
    Name = "${var.vpc_name}-bastion"
  }
}
