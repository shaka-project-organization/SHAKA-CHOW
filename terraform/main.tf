# ============================================================
# FILE: terraform/main.tf
# PURPOSE: The root module. It calls every child module in
# the correct order and passes outputs from one module as
# inputs into the next. Terraform builds a dependency graph
# from these references and applies resources in the right order
# automatically — you never need to specify the order manually.
#
# DEPENDENCY CHAIN:
#   VPC → Security Groups → EKS → ECR
#                                → DNS/Cert
#                                → Observability (Helm, needs EKS)
# ============================================================

# ─────────────────────────────────────────────
# DATA SOURCES
# Data sources READ existing AWS resources without
# creating them. We read the current AWS account ID
# and the caller's identity for use in IAM policies.
# ─────────────────────────────────────────────

# Fetches your AWS account ID (12-digit number).
# Used to construct ARNs like:
#   arn:aws:ecr:us-east-1:123456789012:repository/shakachow-backend
data "aws_caller_identity" "current" {}

# Fetches metadata about the current AWS region.
# Used to reference the region in resource ARNs
# without hardcoding "us-east-1" everywhere.
data "aws_region" "current" {}

# ─────────────────────────────────────────────
# MODULE: VPC
# Creates the entire network layer:
#   - 1 VPC
#   - 2 public subnets (ALB, NAT Gateway)
#   - 2 private subnets (EKS nodes)
#   - 2 isolated subnets (database)
#   - 1 Internet Gateway
#   - 2 NAT Gateways (one per AZ for HA)
#   - Route tables for each subnet tier
# ─────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  # Pass top-level variables down into the module
  cluster_name          = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  isolated_subnet_cidrs = var.isolated_subnet_cidrs
  environment           = var.environment
}

# ─────────────────────────────────────────────
# MODULE: SECURITY GROUPS
# Creates firewall rules for every tier.
# Takes the VPC ID from the VPC module output.
# Rule summary:
#   ALB SG:  ingress 80/443 from 0.0.0.0/0
#   Node SG: ingress all from ALB SG only
#   DB SG:   ingress 27017 from Node SG only
# ─────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  # module.vpc.vpc_id references the "vpc_id" output
  # defined in modules/vpc/outputs.tf. Terraform sees
  # this reference and knows security_groups must be
  # created AFTER vpc. You never specify order manually.
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

# ─────────────────────────────────────────────
# MODULE: ECR
# Creates two private Docker image repositories:
#   - shakachow-backend
#   - shakachow-frontend
# ECR repositories must exist BEFORE the CI/CD
# pipeline tries to push images to them.
# Created early so you can push images while
# EKS is still spinning up (EKS takes ~15 min).
# ─────────────────────────────────────────────
module "ecr" {
  source      = "./modules/ecr"
  environment = var.environment
}

# ─────────────────────────────────────────────
# MODULE: DNS AND CERTIFICATE
# Creates:
#   - ACM TLS certificate for *.engrshakacloud.online
#   - DNS validation records in Route 53
#   - Waits for certificate to be issued (can take 2-5 min)
# The certificate ARN is passed to the Ingress manifest
# as an annotation so the ALB terminates SSL.
# ─────────────────────────────────────────────
module "dns_and_cert" {
  source = "./modules/dns-and-cert"

  domain_name       = var.domain_name
  app_subdomain     = var.app_subdomain
  grafana_subdomain = var.grafana_subdomain
  environment       = var.environment
}

# ─────────────────────────────────────────────
# MODULE: EKS
# Creates:
#   - EKS control plane (managed by AWS)
#   - Managed node group (EC2 instances in private subnets)
#   - OIDC provider (for IRSA — pod-level IAM roles)
#   - IAM roles for cluster, nodes, ALB controller
#   - EKS add-ons: CoreDNS, kube-proxy, vpc-cni, ebs-csi-driver
#   - aws-load-balancer-controller (Helm)
# This is the most complex module and takes ~15 minutes.
# ─────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  aws_region         = var.aws_region
  environment        = var.environment

  # Network inputs — from vpc module outputs
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_security_group = module.security_groups.node_sg_id

  # Node group sizing
  node_instance_type = var.node_instance_type
  node_desired_count = var.node_desired_count
  node_min_count     = var.node_min_count
  node_max_count     = var.node_max_count

  # ECR access — nodes need permission to pull images
  ecr_repository_arns = [
    module.ecr.frontend_repository_arn,
    module.ecr.backend_repository_arn,
  ]
}

# ─────────────────────────────────────────────
# MODULE: OBSERVABILITY
# Installs into the EKS cluster via Helm:
#   - kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
#   - metrics-server (required for HPA)
# Must run AFTER EKS is ready because it
# installs charts into the running cluster.
# ─────────────────────────────────────────────
module "observability" {
  source = "./modules/observability"

  # Grafana config
  grafana_admin_password    = var.grafana_admin_password
  grafana_hostname          = "${var.grafana_subdomain}.${var.domain_name}"
  prometheus_retention_days = var.prometheus_retention_days
  certificate_arn           = module.dns_and_cert.certificate_arn
  environment               = var.environment

  # Explicit dependency — Terraform won't start this module
  # until the EKS cluster and node group are fully ready.
  # Without this, Helm would try to install before the
  # cluster exists and fail.
  depends_on = [module.eks]
}
