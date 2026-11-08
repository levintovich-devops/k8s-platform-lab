resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}


resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "aws-lab-public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.11.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "aws-lab-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.20.12.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "aws-lab-private-b"
  }
}
