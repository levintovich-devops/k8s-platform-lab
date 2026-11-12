data "aws_vpc" "lab" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

data "aws_subnet" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.existing_vpc_name}-public"]
  }
}

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

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.existing_vpc_name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.existing_vpc_name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_security_group" "bastion" {
  name        = "${var.existing_vpc_name}-bastion-sg"
  description = "Security group for SSM-managed Bastion"
  vpc_id      = data.aws_vpc.lab.id

  tags = {
    Name = "${var.existing_vpc_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id

  description = "Allow outbound HTTPS for SSM"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = data.aws_subnet.public.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  iam_instance_profile = aws_iam_instance_profile.bastion.name
  user_data            = file("${path.module}/cloud-init.yaml")

  tags = {
    Name = "${var.existing_vpc_name}-bastion"
  }
}
