# Preserve existing Terraform state addresses during the naming cleanup.
moved {
  from = aws_subnet.public
  to   = aws_subnet.public_a
}

moved {
  from = aws_route_table_association.public
  to   = aws_route_table_association.public_a
}

moved {
  from = aws_route_table.private
  to   = aws_route_table.private_a
}
