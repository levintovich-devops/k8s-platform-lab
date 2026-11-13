data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_state_bucket
    key    = var.vpc_state_key
    region = var.aws_region
  }
}

data "aws_route_table" "public" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.vpc.outputs.vpc_id]
  }

  filter {
    name   = "route-table-id"
    values = [data.terraform_remote_state.vpc.outputs.public_route_table_id]
  }

  filter {
    name   = "association.subnet-id"
    values = [data.terraform_remote_state.vpc.outputs.public_subnet_id]
  }
}

data "aws_route_table" "private_a" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.vpc.outputs.vpc_id]
  }

  filter {
    name   = "route-table-id"
    values = [data.terraform_remote_state.vpc.outputs.private_route_table_a_id]
  }

  filter {
    name   = "association.subnet-id"
    values = [data.terraform_remote_state.vpc.outputs.private_subnet_a_id]
  }
}

data "aws_route_table" "private_b" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.vpc.outputs.vpc_id]
  }

  filter {
    name   = "route-table-id"
    values = [data.terraform_remote_state.vpc.outputs.private_route_table_b_id]
  }

  filter {
    name   = "association.subnet-id"
    values = [data.terraform_remote_state.vpc.outputs.private_subnet_b_id]
  }
}

locals {
  conflicting_private_default_routes = [
    for route in data.aws_route_table.private_a.routes : route
    if route.cidr_block == "0.0.0.0/0" &&
    try(route.nat_gateway_id, null) != aws_nat_gateway.lab.id
  ]
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name      = "${data.terraform_remote_state.vpc.outputs.vpc_name}-nat-eip"
    ManagedBy = "Terraform"
  }
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.terraform_remote_state.vpc.outputs.public_subnet_id

  tags = {
    Name      = "${data.terraform_remote_state.vpc.outputs.vpc_name}-nat"
    ManagedBy = "Terraform"
  }

  lifecycle {
    precondition {
      condition = anytrue([
        for route in data.aws_route_table.public.routes :
        route.cidr_block == "0.0.0.0/0" &&
        try(route.gateway_id, null) == data.terraform_remote_state.vpc.outputs.internet_gateway_id
      ])
      error_message = "The existing public subnet route table must have a 0.0.0.0/0 route to an Internet Gateway."
    }
  }
}

resource "aws_route" "private_default_ipv4" {
  route_table_id         = data.terraform_remote_state.vpc.outputs.private_route_table_a_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab.id

  lifecycle {
    precondition {
      condition = (
        data.aws_route_table.private_a.id == data.aws_route_table.private_b.id &&
        data.aws_route_table.private_a.id == data.terraform_remote_state.vpc.outputs.private_route_table_a_id &&
        data.aws_route_table.private_b.id == data.terraform_remote_state.vpc.outputs.private_route_table_b_id
      )
      error_message = "The existing private-a and private-b subnets must share one route table for this component."
    }

    precondition {
      condition     = length(local.conflicting_private_default_routes) == 0
      error_message = "The existing private route table has an IPv4 default route that does not target this component's NAT Gateway. Refusing to replace or take ownership of it."
    }
  }
}
