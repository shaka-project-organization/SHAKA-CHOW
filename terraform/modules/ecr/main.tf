# ============================================================
# FILE: terraform/modules/ecr/main.tf
# PURPOSE: Creates two private Docker image registries in AWS —
# one for the frontend image, one for the backend image.
# ECR (Elastic Container Registry) is used instead of Docker Hub
# because:
#   - Image pulls from ECR to EKS are free in the same region
#   - Images stay within your AWS account (no external dependency)
#   - IAM controls who can push/pull — no separate credentials
#   - Automatic vulnerability scanning on every push
# ============================================================

# ─────────────────────────────────────────────
# BACKEND ECR REPOSITORY
# ─────────────────────────────────────────────
resource "aws_ecr_repository" "backend" {
  name = "shakachow-backend"

  # IMMUTABLE tags prevent an image tag from being overwritten.
  # Once you push shakachow-backend:abc123, that tag always
  # points to that exact image forever. This prevents
  # accidental overwrites and makes rollbacks reliable.
  # We still push :latest as a mutable tag for convenience.
  image_tag_mutability = "MUTABLE"
  # Set to IMMUTABLE in strict production environments.

  # Automatically scan every image for vulnerabilities
  # when it is pushed. Results appear in the ECR console
  # under "Scan results" — shows CVEs by severity.
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest using AWS KMS.
  # AES256 uses the default AWS-managed key.
  # For compliance requirements, use "KMS" type with a
  # customer-managed key (CMK) instead.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "shakachow-backend"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# FRONTEND ECR REPOSITORY
# ─────────────────────────────────────────────
resource "aws_ecr_repository" "frontend" {
  name                 = "shakachow-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "shakachow-frontend"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# LIFECYCLE POLICIES
# Without lifecycle policies, every image push
# accumulates indefinitely. 100 builds = 100 images
# stored and billed. Lifecycle policies automatically
# delete old images you no longer need.
# "keep the last 10 tagged images" is a safe default —
# enough history for rollbacks, not wasteful.
# ─────────────────────────────────────────────
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images (by git SHA)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v"]
          # Matches tags like sha-abc1234 or v1.0.0
          countType     = "imageCountMoreThan"
          countNumber   = 10
          # When there are more than 10 matching images,
          # delete the oldest ones automatically.
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
          # Untagged images are usually failed or abandoned builds.
          # Clean them up after 7 days.
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
