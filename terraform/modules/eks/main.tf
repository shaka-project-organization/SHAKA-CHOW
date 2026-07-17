
data "aws_caller_identity" "current" {}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "tls_private_key" "nodes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "nodes" {
  key_name   = "${var.cluster_name}-nodes"
  public_key = tls_private_key.nodes.public_key_openssh
}
resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids             = var.private_subnet_ids
    security_group_ids     = [var.node_security_group]
    endpoint_private_access = true

    endpoint_public_access  = true
  }
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_policy,
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}


resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids


  instance_types = [var.node_instance_type]


  ami_type       = "AL2_x86_64"


  capacity_type  = "ON_DEMAND"


  disk_size = 20


  scaling_config {
    desired_size = var.node_desired_count
    min_size     = var.node_min_count
    max_size     = var.node_max_count
  }

  update_config {
    max_unavailable = 1

  }

  remote_access {
    ec2_ssh_key               = aws_key_pair.nodes.key_name
    source_security_group_ids = [var.node_security_group]
  }

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
    Name                                             = "${var.cluster_name}-node-group"
    Environment                                      = var.environment
    "k8s.io/cluster-autoscaler/enabled"              = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"  = "owned"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  depends_on                  = [aws_eks_node_group.main]
}
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  depends_on                  = [aws_eks_node_group.main]
}

resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn

    }
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }

  depends_on = [aws_eks_node_group.main]
}
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  namespace  = "kube-system"
  wait    = true
  timeout = 600
  # 600 seconds = 10 minutes. The controller image is ~200MB.

  set {
    name  = "clusterName"
    value = var.cluster_name
    # Tells the controller which cluster it is managing.
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
    # Tells the controller which AWS region to create ALBs in.
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lb_controller.metadata[0].name
    # Reference the ServiceAccount we created above.
  }

  set {
    name  = "replicaCount"
    value = "2"

  }

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
