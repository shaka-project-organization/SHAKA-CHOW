
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecr_repository" "frontend" {
  name = "shakachow-frontend"  
}

data "aws_ecr_repository" "backend" {
  name = "shakachow-backend" 
}


module "vpc" {
  source                = "./modules/vpc"
  cluster_name          = var.cluster_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  isolated_subnet_cidrs = var.isolated_subnet_cidrs
  environment           = var.environment
}

module "security_groups" {
  source      = "./modules/security-groups"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

module "dns_and_cert" {
  source = "./modules/dns-and-cert"

  domain_name       = var.domain_name
  app_subdomain     = var.app_subdomain
  grafana_subdomain = var.grafana_subdomain
  environment       = var.environment
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  aws_region      = var.aws_region
  environment     = var.environment

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
    data.aws_ecr_repository.frontend.arn,
    data.aws_ecr_repository.backend.arn,
  ]
}


module "observability" {
  source = "./modules/observability"

  # Grafana config
  grafana_admin_password    = var.grafana_admin_password
  grafana_hostname          = "${var.grafana_subdomain}.${var.domain_name}"
  prometheus_retention_days = var.prometheus_retention_days
  certificate_arn           = module.dns_and_cert.certificate_arn
  environment               = var.environment
  depends_on = [module.eks]
}
