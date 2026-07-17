

output "vpc_id" {
  description = "ID of the created VPC. Referenced by security groups and EKS."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (one per AZ). Used by the ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (one per AZ). EKS nodes run here."
  value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  description = "List of isolated subnet IDs (one per AZ). For databases."
  value       = aws_subnet.isolated[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways. One per AZ."
  value       = aws_nat_gateway.main[*].id
}
