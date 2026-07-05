# ============================================================
# FILE: terraform/modules/security-groups/main.tf
# PURPOSE: Creates security groups — stateful firewalls that
# control what traffic each resource can send and receive.
# The design follows the principle of least privilege:
# each resource only accepts traffic from the resource
# immediately above it in the stack.
#
# TRAFFIC FLOW:
#   Internet → ALB SG (80, 443)
#   ALB SG   → Node SG (all ports — ALB needs dynamic ports)
#   Node SG  → DB SG (27017 MongoDB only)
# ============================================================

# ─────────────────────────────────────────────
# ALB SECURITY GROUP
# The Application Load Balancer is the only resource
# that faces the public internet. It must accept HTTP
# and HTTPS from anywhere (0.0.0.0/0).
# ─────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "shakachow-alb-sg"
  description = "Security group for the Application Load Balancer. Accepts HTTP and HTTPS from the internet."
  vpc_id      = var.vpc_id

  # INBOUND: Allow HTTP from anywhere.
  # HTTP traffic arrives here first, then the ALB
  # redirects it to HTTPS (configured in ingress annotations).
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # 0.0.0.0/0 means any IPv4 address — the entire internet.
  }

  # INBOUND: Allow HTTPS from anywhere.
  # This is where real traffic flows after HTTP redirect.
  # ACM certificate terminates SSL here at the ALB.
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OUTBOUND: Allow all outbound traffic from the ALB.
  # The ALB needs to forward requests to EKS pods on
  # whatever port the pod is listening on (dynamic ports
  # in the 30000-32767 NodePort range, or direct pod IPs
  # when using target-type: ip in the Ingress).
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"      # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shakachow-alb-sg"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# EKS NODE SECURITY GROUP
# Worker nodes only accept traffic from the ALB.
# They are completely invisible to the internet.
# Traffic from the ALB arrives on pod IP addresses
# directly (target-type: ip) or on NodePort range.
# ─────────────────────────────────────────────
resource "aws_security_group" "nodes" {
  name        = "shakachow-node-sg"
  description = "Security group for EKS worker nodes. Only accepts traffic from the ALB and other nodes."
  vpc_id      = var.vpc_id

  # INBOUND: Accept all traffic from the ALB security group.
  # Instead of specifying port ranges, we reference the ALB's
  # security group ID. This is more secure than using CIDR blocks
  # because even if the ALB's IP changes, this rule still works.
  # "source_security_group_id" means: allow traffic from any
  # resource that has this security group attached.
  ingress {
    description              = "All traffic from ALB"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    source_security_group_id = aws_security_group.alb.id
  }

  # INBOUND: Allow nodes to communicate with each other.
  # Required for:
  #   - Pod-to-pod communication across nodes
  #   - EKS control plane to node communication (kubelet)
  #   - CoreDNS queries between pods
  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    # "self = true" means: allow traffic from resources
    # that share this same security group.
  }

  # INBOUND: HTTPS from the EKS control plane.
  # The EKS-managed control plane needs to reach the
  # kubelet API (port 443) on each node for log streaming,
  # exec, and metrics collection.
  ingress {
    description = "EKS control plane to nodes"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # In production, restrict this to the EKS control plane
    # CIDR if you know it. For simplicity we allow all HTTPS.
  }

  # OUTBOUND: Nodes need internet access via NAT Gateway to:
  #   - Pull container images from ECR
  #   - Call AWS APIs (CloudWatch, SSM, S3)
  #   - Download Helm chart dependencies
  egress {
    description = "All outbound traffic via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shakachow-node-sg"
    Environment = var.environment
    # This tag is required by EKS to associate the security
    # group with the cluster for auto-discovery.
    "kubernetes.io/cluster/shakachow-cluster" = "owned"
  }
}

# ─────────────────────────────────────────────
# DATABASE SECURITY GROUP
# Only accepts connections from EKS worker nodes.
# No internet access in any direction — ever.
# ─────────────────────────────────────────────
resource "aws_security_group" "database" {
  name        = "shakachow-db-sg"
  description = "Security group for database tier. Only EKS nodes can connect."
  vpc_id      = var.vpc_id

  # INBOUND: MongoDB connections from EKS nodes only.
  # Port 27017 is MongoDB's default port.
  # If you later add PostgreSQL, add port 5432 here too.
  ingress {
    description              = "MongoDB from EKS nodes"
    from_port                = 27017
    to_port                  = 27017
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.nodes.id
  }

  # OUTBOUND: Allow responses back to EKS nodes.
  # Stateful security groups automatically allow return
  # traffic for established connections, but being explicit
  # here makes the intent clear.
  egress {
    description              = "Responses to EKS nodes"
    from_port                = 0
    to_port                  = 0
    protocol                 = "-1"
    source_security_group_id = aws_security_group.nodes.id
  }

  tags = {
    Name        = "shakachow-db-sg"
    Environment = var.environment
    Tier        = "database"
  }
}
