# ============================================================
# FILE: terraform/modules/eks/iam.tf
# PURPOSE: Every AWS service that needs to call other AWS APIs
# must assume an IAM role. This file creates the roles for:
#   1. EKS cluster control plane
#   2. EKS worker nodes
#   3. VPC CNI add-on (pod networking)
#   4. EBS CSI driver (persistent volumes)
#   5. AWS Load Balancer Controller (creates ALBs)
#
# PRINCIPLE OF LEAST PRIVILEGE:
# Each role gets ONLY the permissions it needs.
# The control plane cannot pull ECR images.
# The nodes cannot create load balancers.
# The ALB controller cannot write to S3.
# ============================================================

# ─────────────────────────────────────────────
# 1. EKS CLUSTER ROLE
# The control plane assumes this role to manage
# networking, register nodes, and write logs.
# ─────────────────────────────────────────────

# Trust policy — defines WHO can assume this role.
# "eks.amazonaws.com" is the EKS service principal,
# meaning AWS EKS is allowed to assume this role.
data "aws_iam_policy_document" "cluster_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    # sts:AssumeRole is the API call that exchanges
    # credentials for temporary role credentials.
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_trust.json
  # .json converts the policy document object into a JSON string.

  tags = { Name = "${var.cluster_name}-cluster-role" }
}

# Attach AWS managed policies to the cluster role.
# AmazonEKSClusterPolicy: allows EKS to manage VPC networking,
# create security group rules, and describe EC2 resources.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# AmazonEKSVPCResourceController: allows EKS to manage
# ENIs (Elastic Network Interfaces) for pod networking.
resource "aws_iam_role_policy_attachment" "cluster_vpc_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ─────────────────────────────────────────────
# 2. EKS NODE GROUP ROLE
# EC2 worker nodes assume this role at startup.
# Needed to: join the cluster, pull images from ECR,
# publish metrics to CloudWatch.
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "nodes_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
      # ec2.amazonaws.com = EC2 instance service principal.
      # This allows EC2 instances (the worker nodes) to
      # assume this role at launch via the instance profile.
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.nodes_trust.json
  tags               = { Name = "${var.cluster_name}-node-role" }
}

# AmazonEKSWorkerNodePolicy: allows nodes to call
# eks:DescribeCluster and ec2:Describe* to join the cluster.
resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# AmazonEKS_CNI_Policy: allows the vpc-cni plugin on each node
# to assign/unassign secondary IP addresses to ENIs for pods.
resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# AmazonEC2ContainerRegistryReadOnly: allows nodes to pull
# Docker images from ANY ECR repository in your account.
# Scoped read-only — nodes cannot push or delete images.
resource "aws_iam_role_policy_attachment" "nodes_ecr_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# CloudWatch agent policy — allows nodes to publish
# custom metrics and container logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "nodes_cloudwatch_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ─────────────────────────────────────────────
# 3. VPC CNI IRSA ROLE
# The vpc-cni pod (not the node) needs its own
# permission to manage ENIs. IRSA gives the pod
# this permission without giving it to the whole node.
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "vpc_cni_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    # AssumeRoleWithWebIdentity = IRSA mechanism.
    # The pod presents a JWT token signed by the EKS OIDC
    # provider, and AWS IAM verifies it and issues temporary
    # credentials for this role.
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      # "Federated" principal = external identity provider.
      # Here that's our EKS cluster's OIDC provider.
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      # Restricts which service accounts can use this role.
      # Only the "aws-node" ServiceAccount in "kube-system"
      # namespace can assume this role. Prevents other pods
      # from hijacking the vpc-cni's AWS permissions.
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_trust.json
  tags               = { Name = "${var.cluster_name}-vpc-cni-role" }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ─────────────────────────────────────────────
# 4. EBS CSI DRIVER IRSA ROLE
# The EBS CSI controller pod needs permission to
# create, attach, detach, and delete EBS volumes.
# Used by Prometheus for persistent metrics storage.
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json
  tags               = { Name = "${var.cluster_name}-ebs-csi-role" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ─────────────────────────────────────────────
# 5. ALB CONTROLLER IRSA ROLE
# The AWS Load Balancer Controller pod needs
# permission to create/manage ALBs, target groups,
# listeners, and security group rules.
# This is the most permissive IRSA role because
# ALB management requires many EC2/ELB API calls.
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "alb_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      # Only the ALB controller's ServiceAccount can assume this role.
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust.json
  tags               = { Name = "${var.cluster_name}-alb-controller-role" }
}

# The ALB Controller IAM policy is complex (100+ permissions).
# We download the official policy document published by AWS
# and attach it directly. This is the recommended approach —
# the policy is maintained by AWS and updated with each release.
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for the AWS Load Balancer Controller"

  # This policy JSON is the official one published by AWS at:
  # https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  # It grants permission to: create/delete ALBs, target groups,
  # listeners, rules, certificates, WAF associations, etc.
  policy = file("${path.module}/alb-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
