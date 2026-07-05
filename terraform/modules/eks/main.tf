# ============================================================
# FILE: terraform/modules/eks/main.tf
# PURPOSE: Creates the entire Kubernetes platform on AWS:
#   1. EKS control plane  — the Kubernetes API server,
#      etcd (state store), scheduler, controller manager.
#      Fully managed by AWS — you never patch or operate it.
#   2. Managed node group — EC2 instances that run your pods.
#      AWS handles OS patching and node replacement.
#   3. Cluster add-ons    — CoreDNS (DNS), kube-proxy (networking),
#      vpc-cni (pod IPs from VPC CIDR), ebs-csi-driver (storage).
#   4. ALB Controller     — watches Ingress objects and
#      creates/updates AWS Application Load Balancers.
# ============================================================

# ─────────────────────────────────────────────
# DATA SOURCES
# Read AWS account info needed for ARN construction
# ─────────────────────────────────────────────

# Fetches the current AWS account ID (12-digit number).
# Used to build ARNs like arn:aws:iam::123456789012:role/...
data "aws_caller_identity" "current" {}

# Reads the TLS certificate from the EKS OIDC issuer endpoint.
# The thumbprint of this certificate is registered with AWS IAM
# so IAM can trust tokens issued by this EKS cluster.
# This is the foundation of IRSA (IAM Roles for Service Accounts).
data "tls_certificate" "eks_oidc" {
  # The OIDC issuer URL looks like:
  # https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Fetches the latest Amazon Linux 2 EKS-optimised AMI.
# This AMI has the kubelet, containerd, and AWS VPC CNI
# plugin pre-installed and configured for the EKS version.
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
  # SSM Parameter Store is where AWS publishes the latest
  # AMI IDs for each EKS version. Using this data source
  # instead of hardcoding an AMI ID means your node group
  # always uses the latest patched image for your K8s version.
}

# ─────────────────────────────────────────────
# SSH KEY PAIR (optional but recommended)
# Allows SSH access to nodes for debugging.
# In production, use SSM Session Manager instead.
# ─────────────────────────────────────────────

# Generate a 4096-bit RSA private key using the TLS provider.
# This key is stored in Terraform state — handle with care.
resource "tls_private_key" "nodes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register the public half of the key with AWS.
# The private key never leaves Terraform state.
# AWS places the public key on each EC2 node at launch.
resource "aws_key_pair" "nodes" {
  key_name   = "${var.cluster_name}-nodes"
  public_key = tls_private_key.nodes.public_key_openssh
}

# ─────────────────────────────────────────────
# EKS CLUSTER (CONTROL PLANE)
# The Kubernetes API server and all control plane
# components. AWS runs this — you only configure it.
# ─────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.cluster_version

  # The IAM role that the EKS control plane assumes.
  # It needs permission to call AWS APIs on your behalf:
  # create ENIs in your VPC, write to CloudWatch Logs, etc.
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # The private subnets where EKS will place the control
    # plane ENIs (network interfaces) for node communication.
    subnet_ids = var.private_subnet_ids

    # Attach the node security group to cluster networking.
    security_group_ids = [var.node_security_group]

    # endpoint_private_access = true means the Kubernetes API
    # server is reachable from inside the VPC (from nodes and
    # from CI/CD runners running aws eks update-kubeconfig).
    endpoint_private_access = true

    # endpoint_public_access = true means the API server also
    # has a public endpoint (protected by IAM auth).
    # This lets you run kubectl from your laptop.
    # Set to false in high-security environments.
    endpoint_public_access  = true
  }

  # Enable control plane logging to CloudWatch.
  # These log types cover the full picture:
  #   api            — every API call made to the cluster
  #   audit          — who did what (compliance/security)
  #   authenticator  — auth token validation events
  #   controllerManager — reconciliation loops
  #   scheduler      — pod scheduling decisions
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Ensure the IAM role exists before creating the cluster.
  # Terraform can usually infer this from resource references,
  # but making it explicit prevents rare race conditions.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_policy,
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# OIDC PROVIDER
# Enables IRSA: IAM Roles for Service Accounts.
# IRSA lets individual Kubernetes pods assume specific
# IAM roles — instead of giving ALL nodes broad permissions,
# only the pods that need AWS access get it.
# Example: Only the ALB Controller pod gets permission
# to create/modify load balancers. Your app pods get nothing.
# ─────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "eks" {
  # The OIDC URL from the EKS cluster — this is the
  # "identity provider" that issues tokens to service accounts.
  client_id_list  = ["sts.amazonaws.com"]
  # sts.amazonaws.com = AWS Security Token Service.
  # Tokens are exchanged here for temporary IAM credentials.

  # The SHA1 thumbprint of the OIDC issuer's TLS certificate.
  # IAM uses this to verify tokens actually came from your cluster.
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  # The full OIDC issuer URL from the cluster.
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ─────────────────────────────────────────────
# MANAGED NODE GROUP
# EC2 instances that run your application pods.
# "Managed" means AWS handles:
#   - Node provisioning and registration with the cluster
#   - OS patching and security updates
#   - Graceful draining during node replacement
#   - Auto-healing (replacing unhealthy nodes)
# ─────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"

  # The IAM role nodes assume. Needs permission to:
  # pull images from ECR, write metrics to CloudWatch,
  # register with the cluster, and use VPC CNI.
  node_role_arn = aws_iam_role.nodes.arn

  # Place nodes in private subnets — they are not
  # reachable from the internet, only from the ALB.
  subnet_ids = var.private_subnet_ids

  # Instance configuration
  instance_types = [var.node_instance_type]
  # t3.medium = 2 vCPU, 4GB RAM.
  # Comfortable for: 2 frontend pods + 2 backend pods
  # + Prometheus + Grafana + metrics-server.

  # Use the latest EKS-optimised Amazon Linux 2 AMI.
  # ami_type = AL2_x86_64 for standard x86_64 instances.
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  # ON_DEMAND = always available, predictable pricing.
  # SPOT = cheaper (60-90% off) but can be interrupted.
  # Use SPOT for non-critical workloads / dev environments.

  disk_size = 20
  # 20GB EBS volume per node.
  # Stores the OS, container images (pulled from ECR),
  # and ephemeral pod storage.

  # Auto-scaling configuration.
  # desired_size = how many nodes to start with.
  # min_size     = never scale below this (always have 2
  #                for multi-AZ high availability).
  # max_size     = upper limit for the cluster autoscaler.
  scaling_config {
    desired_size = var.node_desired_count
    min_size     = var.node_min_count
    max_size     = var.node_max_count
  }

  # Rolling update configuration.
  # max_unavailable = during a node group update (e.g. AMI
  # upgrade), allow at most 1 node to be unavailable at once.
  # This keeps your app running during node replacements.
  update_config {
    max_unavailable = 1
  }

  # Attach the SSH key to each node for emergency debugging.
  remote_access {
    ec2_ssh_key               = aws_key_pair.nodes.key_name
    source_security_group_ids = [var.node_security_group]
    # Only allow SSH from resources in the node security group
    # (i.e., other nodes). Not from the internet.
  }

  # Labels applied to each Kubernetes node object.
  # Used in pod scheduling rules (nodeSelector, nodeAffinity).
  labels = {
    role        = "worker"
    environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
  ]

  tags = {
    Name        = "${var.cluster_name}-node-group"
    Environment = var.environment
    # This tag enables the Cluster Autoscaler to discover
    # and manage this node group.
    "k8s.io/cluster-autoscaler/enabled"              = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"  = "owned"
  }
}

# ─────────────────────────────────────────────
# EKS ADD-ONS
# Managed plugins that extend Kubernetes with
# AWS-specific functionality. AWS keeps these
# updated and patches security vulnerabilities.
# ─────────────────────────────────────────────

# CoreDNS — the cluster's internal DNS server.
# Every Kubernetes Service gets a DNS name like:
# shakachow-backend.shakachow.svc.cluster.local
# Pods use CoreDNS to resolve these names to ClusterIPs.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = "v1.11.1-eksbuild.4"
  resolve_conflicts_on_update = "OVERWRITE"
  # OVERWRITE = if you've customised the CoreDNS config,
  # the addon update will overwrite your changes.
  # Use PRESERVE to keep customisations during updates.

  depends_on = [aws_eks_node_group.main]
  # CoreDNS pods need nodes to run on — wait for nodes first.
}

# kube-proxy — runs on every node and maintains iptables
# rules that implement Kubernetes Services.
# When a pod connects to a ClusterIP, kube-proxy's iptables
# rules redirect the traffic to one of the healthy backend pods.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.29.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
}

# VPC CNI — assigns real VPC IP addresses to pods.
# Without this, pods would use an overlay network with
# separate IP ranges. With vpc-cni, each pod gets an
# IP from your VPC CIDR (e.g. 10.0.10.45) and is
# directly routable within the VPC — no NAT overhead.
# The ALB uses these IPs for direct pod targeting
# (target-type: ip in Ingress annotations).
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.16.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"

  # Grant the vpc-cni pod permission to manage ENIs in your VPC.
  # This is IRSA in action — only this specific service account
  # gets permission to call EC2 network APIs.
  service_account_role_arn = aws_iam_role.vpc_cni.arn
}

# EBS CSI Driver — allows Kubernetes PersistentVolumeClaims
# to provision AWS EBS volumes automatically.
# Prometheus uses this to persist metrics data across pod restarts.
# Without it, all data would be lost every time a Prometheus pod restarts.
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.26.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  # IRSA: only the EBS CSI controller pods can create/delete EBS volumes.

  depends_on = [aws_eks_node_group.main]
}

# ─────────────────────────────────────────────
# AWS LOAD BALANCER CONTROLLER (Helm)
# Watches Kubernetes Ingress objects in your cluster.
# When you apply k8s/ingress/ingress.yaml, this controller
# reads the annotations and creates a real AWS ALB
# with the specified listeners, target groups, and SSL cert.
# It also manages the ALB lifecycle — updates rules when
# the Ingress changes, deletes the ALB when Ingress is deleted.
# ─────────────────────────────────────────────

# Create the Kubernetes namespace for the controller.
resource "kubernetes_namespace" "aws_lb_controller" {
  metadata {
    name = "kube-system"
    # kube-system is the standard namespace for cluster
    # infrastructure components. The LB controller lives here.
  }
  # Only creates if it doesn't exist — kube-system usually
  # already exists but this prevents errors on fresh clusters.
  lifecycle {
    ignore_changes = [metadata]
  }
}

# Create a Kubernetes ServiceAccount with an annotation
# linking it to the ALB Controller's IAM role (IRSA).
# The controller pod uses this ServiceAccount — when it
# calls AWS APIs, it automatically gets the IAM role's permissions.
resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      # This annotation is the core of IRSA.
      # It tells the OIDC provider: "pods using this service
      # account should be allowed to assume this IAM role."
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

# Install the ALB Controller via Helm chart.
# Helm is the Kubernetes package manager — it templated
# the controller's Deployment, RBAC rules, CRDs, and
# ConfigMaps into a single installable package.
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  # Official AWS Helm chart repository.
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  namespace  = "kube-system"

  # Tell the controller which cluster and region it is running in.
  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  # Use the IRSA-annotated ServiceAccount we created above.
  # The controller pod will assume the ALB IAM role via this account.
  set {
    name  = "serviceAccount.create"
    value = "false"
    # We created the ServiceAccount in Terraform above —
    # tell Helm not to create a duplicate.
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lb_controller.metadata[0].name
  }

  # Run 2 replicas of the controller for high availability.
  # If one pod crashes, the other continues managing ALBs.
  set {
    name  = "replicaCount"
    value = "2"
  }

  # VPC ID so the controller knows which VPC to create ALBs in.
  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_service_account.aws_lb_controller,
    aws_iam_role_policy_attachment.alb_controller,
  ]
}
