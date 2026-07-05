# ============================================================
# FILE: terraform/modules/eks/outputs.tf
# ============================================================

output "cluster_name" {
  # Used by CI/CD: aws eks update-kubeconfig --name <this>
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  # The HTTPS URL of the Kubernetes API server.
  # Used by the kubernetes and helm Terraform providers
  # to connect to the cluster and install resources.
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  # Base64-encoded certificate authority data.
  # kubectl uses this to verify the API server's TLS cert.
  # base64decode() is called in versions.tf to convert it.
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  # ARN of the OIDC identity provider.
  # Needed when creating additional IRSA roles outside this module.
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_role_arn" {
  description = "IAM role ARN of the node group"
  value       = aws_iam_role.nodes.arn
}
