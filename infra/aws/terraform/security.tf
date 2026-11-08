resource "aws_security_group" "bastion" {
  name        = "${var.vpc_name}-bastion-sg"
  description = "Security group for SSM-managed Bastion"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "${var.vpc_name}-bastion-sg"
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