data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_state_bucket
    key    = var.vpc_state_key
    region = var.aws_region
  }
}

locals {
  vpc = data.terraform_remote_state.vpc.outputs
  azs = {
    a = {
      public_subnet_id      = local.vpc.public_subnet_a_id
      private_route_table_id = local.vpc.private_route_table_a_id
    }
    b = {
      public_subnet_id      = local.vpc.public_subnet_b_id
      private_route_table_id = local.vpc.private_route_table_b_id
    }
  }
}

data "aws_route_table" "public" {
  route_table_id = local.vpc.public_route_table_id
}

data "aws_route_table" "private" {
  for_each       = local.azs
  route_table_id = each.value.private_route_table_id
}

resource "aws_eip" "nat" {
  for_each = local.azs
  domain   = "vpc"

  tags = {
    Name      = "${local.vpc.vpc_name}-nat-${each.key}-eip"
    ManagedBy = "Terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each      = local.azs
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.public_subnet_id

  tags = {
    Name      = "${local.vpc.vpc_name}-nat-${each.key}"
    ManagedBy = "Terraform"
  }

  lifecycle {
    precondition {
      condition = anytrue([
        for route in data.aws_route_table.public.routes :
        route.cidr_block == "0.0.0.0/0" &&
        try(route.gateway_id, null) == local.vpc.internet_gateway_id
      ])
      error_message = "The public route table must have a default IPv4 route to the VPC Internet Gateway."
    }
  }
}

resource "aws_route" "private_default_ipv4" {
  for_each               = local.azs
  route_table_id         = each.value.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id

  lifecycle {
    precondition {
      condition = alltrue([
        for route in data.aws_route_table.private[each.key].routes :
        route.cidr_block != "0.0.0.0/0"
      ])
      error_message = "The private route table already has a default IPv4 route. Remove the existing route before deploying this module."
    }
  }
}
