output "nat_gateway_ids" {
  description = "NAT Gateway IDs by Availability Zone suffix."
  value       = { for az, nat in aws_nat_gateway.nat : az => nat.id }
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway Elastic IP addresses by Availability Zone suffix."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "public_subnet_ids" {
  description = "Public subnet IDs hosting NAT Gateways, keyed by Availability Zone suffix."
  value       = { for az, config in local.azs : az => config.public_subnet_id }
}

output "private_default_routes" {
  description = "Private default routes by Availability Zone suffix."
  value = {
    for az, route in aws_route.private_default_ipv4 :
    az => {
      route_table_id         = route.route_table_id
      destination_cidr_block = route.destination_cidr_block
      nat_gateway_id         = route.nat_gateway_id
    }
  }
}
