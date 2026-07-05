# ============================================================
# FILE: terraform/modules/ecr/variables.tf
# ============================================================
variable "environment" {
  description = "Deployment environment (production, staging, development)"
  type        = string
}
