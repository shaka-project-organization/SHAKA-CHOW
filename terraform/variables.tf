

variable "aws_region" {
  description = "AWS region where all resources are deployed. Must match the region your Route 53 hosted zone and ACM certificate are in."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name. Used in resource names and tags to distinguish prod from staging."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "environment must be one of: production, staging, development."
  }
}

# ─────────────────────────────────────────────
# NETWORKING
# ─────────────────────────────────────────────

variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the entire VPC.
    10.0.0.0/16 gives you 65,536 IP addresses.
    The subnets will be carved from this range.
    Do not overlap this with any other VPC you
    might want to peer with in the future.
  EOT
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs to deploy into. Resources (EKS nodes, NAT Gateways) are spread across both for high availability. If one AZ fails, the other continues serving traffic."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets — one per AZ. Only the ALB and NAT Gateway live here. These subnets have a route to the Internet Gateway."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  # /24 = 256 addresses each. More than enough for ALB ENIs and NAT GWs.
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ. EKS worker nodes live here. They can reach the internet via NAT Gateway but cannot be reached from outside."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  # /24 gives 256 addresses. EKS with vpc-cni assigns one IP per pod,
  # so this limits you to ~250 pods per subnet. Increase to /23 if needed.
}

variable "isolated_subnet_cidrs" {
  description = "CIDR blocks for isolated (database) subnets — one per AZ. No route to the internet in either direction. Only the EKS node security group can reach these."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# ─────────────────────────────────────────────
# EKS CLUSTER
# ─────────────────────────────────────────────

variable "cluster_name" {
  description = "Name of the EKS cluster. Used in kubeconfig, IAM roles, and CloudWatch log group names."
  type        = string
  default     = "shakachow-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane. AWS supports the last 3 minor versions. Check https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for supported versions."
  type        = string
  default     = "1.32"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes. t3.medium (2 vCPU, 4GB RAM) comfortably runs the frontend, backend, Prometheus, and Grafana pods."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_count" {
  description = "Desired number of worker nodes at steady state."
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum worker nodes. Never scale below this. Set to 2 so you always have nodes in both AZs."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum worker nodes the cluster autoscaler can scale up to during traffic spikes."
  type        = number
  default     = 4
}

# ─────────────────────────────────────────────
# DNS AND CERTIFICATES
# ─────────────────────────────────────────────

variable "domain_name" {
  description = "Your root domain name. Must already have a Route 53 hosted zone in your AWS account."
  type        = string
  default     = "engrshakacloud.online"
}

variable "app_subdomain" {
  description = "Subdomain for the ShakaChow application. The full URL will be shakachow.engrshakacloud.online."
  type        = string
  default     = "shakachow"
}

variable "grafana_subdomain" {
  description = "Subdomain for the Grafana monitoring dashboard."
  type        = string
  default     = "grafana"
}

# ─────────────────────────────────────────────
# OBSERVABILITY
# ─────────────────────────────────────────────

variable "grafana_admin_password" {
  description = "Admin password for the Grafana dashboard. Mark this sensitive so Terraform never prints it in plan/apply output or state diffs."
  type        = string
  sensitive   = true
  # Set this in terraform.tfvars:
  # grafana_admin_password = "your-strong-password"
}

variable "prometheus_retention_days" {
  description = "How many days Prometheus keeps metrics data. More days = more disk. 15 days is a good balance for a portfolio project."
  type        = number
  default     = 15
}
