

output "vpc_id" {
  description = "ID of the VPC. Used to verify resource placement in the AWS console and referenced in future Terraform modules."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets. The ALB and NAT Gateways live here."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the two private subnets. EKS worker nodes run here."
  value       = module.vpc.private_subnet_ids
}

# ─────────────────────────────────────────────
# EKS OUTPUTS
# ─────────────────────────────────────────────

output "cluster_name" {
  description = "EKS cluster name. Set this as the EKS_CLUSTER_NAME GitHub Secret so CI/CD can run: aws eks update-kubeconfig --name <this value>"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "HTTPS endpoint for the EKS Kubernetes API server. Used by kubectl and the Kubernetes/Helm Terraform providers."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the EKS cluster. Required for TLS verification when connecting to the API server."
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
  # sensitive=true prevents this from printing in terraform plan/apply output.
  # Retrieve it with: terraform output -raw cluster_ca_certificate
}

output "configure_kubectl_command" {
  description = "Run this command locally after terraform apply to configure kubectl on your machine."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ─────────────────────────────────────────────
# ECR OUTPUTS
# ─────────────────────────────────────────────

output "ecr_frontend_repository_url" {
  description = "Full ECR URL for the frontend image. Use this in your Dockerfile tag and CI/CD pipeline. Format: <account>.dkr.ecr.<region>.amazonaws.com/shakachow-frontend"
  value       = data.aws_ecr_repository.frontend.arn
}

output "ecr_backend_repository_url" {
  description = "Full ECR URL for the backend image."
  value       = data.aws_ecr_repository.backend.arn
}

output "ecr_login_command" {
  description = "Run this command to authenticate Docker with ECR before pushing images."
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ─────────────────────────────────────────────
# DNS AND CERTIFICATE OUTPUTS
# ─────────────────────────────────────────────

output "certificate_arn" {
  description = "ARN of the ACM certificate. Add this to the Kubernetes Ingress annotation: alb.ingress.kubernetes.io/certificate-arn"
  value       = module.dns_and_cert.certificate_arn
}

output "app_url" {
  description = "Public URL of the ShakaChow application."
  value       = "https://${var.app_subdomain}.${var.domain_name}"
}

output "grafana_url" {
  description = "Public URL of the Grafana monitoring dashboard."
  value       = "https://${var.grafana_subdomain}.${var.domain_name}"
}

# ─────────────────────────────────────────────
# SUMMARY OUTPUT
# ─────────────────────────────────────────────

output "deployment_summary" {
  description = "Quick reference summary of all key values after a successful apply."
  value       = <<-EOT

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🍛 ShakaChow Infrastructure — Deployment Complete
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    App URL     : https://${var.app_subdomain}.${var.domain_name}
    Grafana     : https://${var.grafana_subdomain}.${var.domain_name}
    EKS Cluster : ${module.eks.cluster_name}
    Region      : ${var.aws_region}

    Next steps:
    1. Run: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    2. Run: kubectl apply -f k8s/namespaces/namespaces.yaml
    3. Run: kubectl apply -f k8s/secrets/backend-secret.yaml
    4. Run: kubectl apply -f k8s/ --recursive
    5. Push code to main → CI/CD deploys images automatically

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EOT
}
