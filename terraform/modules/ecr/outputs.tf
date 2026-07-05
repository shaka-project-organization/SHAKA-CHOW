# ============================================================
# FILE: terraform/modules/ecr/outputs.tf
# PURPOSE: Exposes ECR repository URLs and ARNs so the root
# module can pass them to EKS (for pull permissions) and
# print them in the final terraform apply summary.
# ============================================================

output "frontend_repository_url" {
  # The full URI used to tag and push the frontend Docker image.
  # Format: 123456789012.dkr.ecr.us-east-1.amazonaws.com/shakachow-frontend
  # CI/CD uses this in: docker build -t <this_value>:<tag> ./frontend
  description = "Full ECR URI for the frontend repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_repository_url" {
  # Same pattern for the backend image.
  # CI/CD uses this in: docker build -t <this_value>:<tag> ./backend
  description = "Full ECR URI for the backend repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_arn" {
  # The ARN is used in IAM policy statements to grant EKS
  # node group permission to pull images from this specific repo.
  # ARN format: arn:aws:ecr:us-east-1:123456789012:repository/shakachow-frontend
  description = "ARN of the frontend ECR repository — used in IAM policies"
  value       = aws_ecr_repository.frontend.arn
}

output "backend_repository_arn" {
  description = "ARN of the backend ECR repository — used in IAM policies"
  value       = aws_ecr_repository.backend.arn
}
