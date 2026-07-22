output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.private_db[*].id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}
