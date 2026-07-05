# ============================================================
# FILE: terraform/versions.tf
# PURPOSE: Locks every provider to an exact version range.
# WHY THIS MATTERS: Without version locks, "terraform init"
# could silently pull a newer provider version that has
# breaking changes, causing a plan that worked yesterday
# to fail today. Locking versions makes your infrastructure
# fully reproducible across machines and CI runs.
# ============================================================

terraform {
  # Minimum Terraform CLI version required to use this code.
  # We use 1.6+ for the "terraform test" framework and
  # improved provider dependency locking.
  required_version = ">= 1.6.0"

  required_providers {
    # AWS provider — manages every AWS resource in this project:
    # VPC, subnets, EKS, ECR, IAM, ACM, Route 53, Security Groups.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
      # "~> 5.31" means: >= 5.31.0 and < 6.0.0
      # Allows patch updates (5.31.1, 5.31.2) but blocks
      # major version upgrades that could have breaking changes.
    }

    # Kubernetes provider — manages resources INSIDE the EKS cluster:
    # Namespaces, ConfigMaps, Secrets, ServiceAccounts.
    # Note: Deployments, Services, Ingress are handled by kubectl
    # in the CI/CD pipeline, not Terraform. Terraform only manages
    # the cluster-level configuration objects.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }

    # Helm provider — installs Helm charts into the EKS cluster.
    # Used here for: kube-prometheus-stack (Prometheus + Grafana),
    # AWS Load Balancer Controller, metrics-server.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    # TLS provider — generates the RSA key pair used for
    # EKS node SSH access (stored in AWS Key Pair).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state backend — stores terraform.tfstate in S3
  # so the state is shared across your machine, teammates,
  # and CI/CD pipelines. Without this, state only lives locally
  # and concurrent runs corrupt it.
  # DynamoDB table provides state locking — prevents two
  # "terraform apply" runs from modifying infrastructure at the
  # same time and corrupting the state file.
  #
  # CREATE THESE MANUALLY BEFORE "terraform init":
  #   aws s3 mb s3://shakachow-terraform-state --region us-east-1
  #   aws dynamodb create-table \
  #     --table-name shakachow-terraform-locks \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST \
  #     --region us-east-1
  backend "s3" {
    bucket         = "shakachow-terraform-state"
    key            = "shakachow/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "shakachow-terraform-locks"
    encrypt        = true
    # encrypt=true enables AES-256 server-side encryption on
    # the state file. The state can contain sensitive values
    # (passwords, private keys) so encryption is essential.
  }
}

# ─────────────────────────────────────────────
# AWS PROVIDER CONFIGURATION
# Tells the AWS provider which region to deploy into
# and adds default tags to every AWS resource it creates.
# Default tags appear on every EC2 instance, subnet,
# security group, etc. in the AWS console — essential
# for cost tracking and resource identification.
# ─────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "shakachow"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "shaka"
    }
  }
}

# ─────────────────────────────────────────────
# KUBERNETES PROVIDER CONFIGURATION
# Tells the Kubernetes provider how to connect to
# the EKS cluster that Terraform just created.
# We use the cluster endpoint and CA certificate
# from the EKS module output, and generate a
# temporary auth token using the AWS CLI.
# ─────────────────────────────────────────────
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    # This block runs "aws eks get-token" to generate a
    # short-lived authentication token for the API server.
    # This is the same mechanism kubectl uses under the hood.
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region",       var.aws_region,
    ]
  }
}

# ─────────────────────────────────────────────
# HELM PROVIDER CONFIGURATION
# Same connection details as the Kubernetes provider.
# Helm talks to the same Kubernetes API server to
# install and manage chart releases.
# ─────────────────────────────────────────────
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region",       var.aws_region,
      ]
    }
  }
}
