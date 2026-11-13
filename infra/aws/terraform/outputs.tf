output "vpc_name" {
  description = "Name tag of the permanent VPC."
  value       = var.vpc_name
}

output "vpc_id" {
  description = "ID of the permanent VPC."
  value       = aws_vpc.lab.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the permanent VPC."
  value       = aws_vpc.lab.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway."
  value       = aws_internet_gateway.lab.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "IPv4 CIDR block of the public subnet."
  value       = aws_subnet.public.cidr_block
}

output "public_subnet_availability_zone" {
  description = "Availability Zone of the public subnet."
  value       = aws_subnet.public.availability_zone
}

output "private_subnet_a_id" {
  description = "ID of the first private subnet."
  value       = aws_subnet.private_a.id
}

output "private_subnet_a_cidr" {
  description = "IPv4 CIDR block of the first private subnet."
  value       = aws_subnet.private_a.cidr_block
}

output "private_subnet_a_availability_zone" {
  description = "Availability Zone of the first private subnet."
  value       = aws_subnet.private_a.availability_zone
}

output "private_subnet_b_id" {
  description = "ID of the second private subnet."
  value       = aws_subnet.private_b.id
}

output "private_subnet_b_cidr" {
  description = "IPv4 CIDR block of the second private subnet."
  value       = aws_subnet.private_b.cidr_block
}

output "private_subnet_b_availability_zone" {
  description = "Availability Zone of the second private subnet."
  value       = aws_subnet.private_b.availability_zone
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_a_id" {
  description = "Route table ID associated with the first private subnet."
  value       = aws_route_table_association.private_a.route_table_id
}

output "private_route_table_b_id" {
  description = "Route table ID associated with the second private subnet."
  value       = aws_route_table_association.private_b.route_table_id
}
