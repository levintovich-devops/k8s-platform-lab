
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
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone_a

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = var.availability_zone_a

  tags = {
    Name = "${var.vpc_name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = var.availability_zone_b

  tags = {
    Name = "${var.vpc_name}-private-b"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = var.public_route_cidr
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

