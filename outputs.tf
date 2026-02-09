output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

# Output your public IP
output "ec2_public_ip" {
  description = "The public IP of the Nginx server"
  value       = aws_instance.public_server.public_ip
}

output "rds_endpoint" {
  description = "The connection endpoint for the database"
  value       = aws_db_instance.postgres.address
} 