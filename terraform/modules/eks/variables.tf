# ============================================================
# FILE: terraform/modules/eks/variables.tf
# ============================================================
variable "cluster_name"       { type = string }
variable "cluster_version"    { type = string }
variable "aws_region"         { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_security_group"{ type = string }
variable "node_instance_type" { type = string }
variable "node_desired_count" { type = number }
variable "node_min_count"     { type = number }
variable "node_max_count"     { type = number }
variable "ecr_repository_arns"{ type = list(string) }
