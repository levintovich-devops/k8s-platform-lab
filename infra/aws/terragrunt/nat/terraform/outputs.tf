output "nat_gateway_id" {
  description = "ID of the NAT Gateway created in the existing public subnet."
  value       = aws_nat_gateway.lab.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP address allocated to the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "public_subnet_id" {
  description = "Existing public subnet hosting the NAT Gateway."
  value       = data.terraform_remote_state.vpc.outputs.public_subnet_id
}

output "private_route_table_id" {
  description = "Existing shared private route table receiving the NAT default route."
  value       = data.terraform_remote_state.vpc.outputs.private_route_table_a_id
}

output "private_default_route" {
  description = "The destination and NAT Gateway target of the route managed by this component."
  value = {
    destination_cidr_block = aws_route.private_default_ipv4.destination_cidr_block
    nat_gateway_id         = aws_route.private_default_ipv4.nat_gateway_id
  }
}
