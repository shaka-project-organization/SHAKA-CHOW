# ============================================================
# FILE: terraform/modules/observability/main.tf
# PURPOSE: Installs the full monitoring stack into EKS using
# Helm charts — the Kubernetes package manager.
#
# WHAT GETS INSTALLED:
#   kube-prometheus-stack (one chart, multiple components):
#     - Prometheus       → scrapes metrics from every pod every 15s
#     - Grafana          → visualises metrics in dashboards
#     - Alertmanager     → routes alerts to email/Slack
#     - node-exporter    → exposes OS-level metrics per node
#     - kube-state-metrics → exposes Kubernetes object metrics
#   metrics-server:
#     - Feeds CPU/memory data to HPA (HorizontalPodAutoscaler)
#     - Required for "kubectl top pods/nodes" to work
# ============================================================

# ─────────────────────────────────────────────
# MONITORING NAMESPACE
# All observability components run in the "monitoring"
# namespace, isolated from the application namespace.
# This prevents a misbehaving app from affecting monitoring,
# and lets you apply different RBAC policies to each namespace.
# ─────────────────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      # This label tells Prometheus to discover ServiceMonitors
      # (custom resources that configure scrape targets) in this namespace.
      "prometheus.io/scrape" = "true"
    }
  }
}

# ─────────────────────────────────────────────
# METRICS SERVER
# Lightweight in-cluster resource metrics collector.
# Collects CPU and memory from each node's kubelet
# and exposes them via the Kubernetes Metrics API.
# Required by:
#   - HorizontalPodAutoscaler (HPA) — to trigger pod scaling
#   - kubectl top pods / kubectl top nodes
# Without metrics-server, HPA cannot function and will
# show "unknown" for current CPU utilisation.
# ─────────────────────────────────────────────
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"
  # kube-system = standard namespace for cluster infrastructure.

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
    # In EKS, kubelet certificates are self-signed.
    # This flag tells metrics-server to skip TLS verification
    # when scraping kubelets. Required in EKS environments.
  }
}

# ─────────────────────────────────────────────
# KUBE-PROMETHEUS-STACK
# The industry-standard Kubernetes monitoring bundle.
# One Helm chart installs and pre-configures everything:
# Prometheus, Grafana, Alertmanager, exporters, and
# a suite of pre-built Kubernetes dashboards.
# ─────────────────────────────────────────────
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  # Deploy into the "monitoring" namespace we created above.

  # wait = true: Terraform waits until all pods in this
  # Helm release are Running before marking the resource complete.
  # This prevents dependent resources from starting too early.
  wait    = true
  timeout = 600
  # 600 seconds (10 minutes) timeout. Prometheus and Grafana
  # images are large — allow enough time to pull them.

  # ── PROMETHEUS CONFIGURATION ──────────────
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.prometheus_retention_days}d"
    # How long Prometheus keeps metrics data.
    # "15d" = 15 days. After this, old data is automatically
    # deleted from the PersistentVolume to free disk space.
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp2"
    # gp2 = AWS General Purpose SSD (EBS volume).
    # The EBS CSI driver provisions this automatically when
    # Prometheus starts, creating a persistent disk for metrics.
    # Without this, all metrics are lost every time the pod restarts.
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
    # 10GB EBS volume for Prometheus data.
    # At 15 days retention, 10GB comfortably stores metrics for
    # a small cluster. Increase if you have many pods or high cardinality.
  }

  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = "15s"
    # How often Prometheus scrapes metrics from each target.
    # 15 seconds is the standard interval — granular enough
    # to catch short spikes without overwhelming storage.
  }

  # ── ALERT RULES ───────────────────────────
  # These rules fire alerts when conditions are met.
  # Alertmanager receives the alert and routes it to
  # the configured receivers (email, Slack, PagerDuty).

  set {
    # Fire alert if a pod restarts more than 3 times in 5 minutes.
    # This indicates a CrashLoopBackOff — the container is repeatedly
    # crashing. Usually caused by a misconfigured env var, missing
    # secret, or application error on startup.
    name  = "defaultRules.rules.kubeStateMetrics"
    value = "true"
  }

  set {
    name  = "defaultRules.rules.alertmanager"
    value = "true"
    # Enable Alertmanager's own health monitoring rules.
  }

  # ── GRAFANA CONFIGURATION ─────────────────
  set {
    name  = "grafana.enabled"
    value = "true"
    # Enable the Grafana sub-chart within kube-prometheus-stack.
  }

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
    # The admin password is passed from the Terraform variable
    # (set in terraform.tfvars, never committed to git).
    # Access Grafana at grafana.engrshakacloud.online
    # with username "admin" and this password.
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"
    # Create a Kubernetes Ingress for Grafana so the ALB
    # Controller provisions an ALB route to it.
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
    # "alb" tells the ALB Controller this Ingress is for it.
    # The controller only manages Ingress objects with this class.
  }

  set {
    name  = "grafana.ingress.hosts[0]"
    value = var.grafana_hostname
    # "grafana.engrshakacloud.online" — the hostname the ALB
    # uses to route traffic to Grafana pods.
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
    # Create a public-facing ALB (not internal).
    # The backslashes escape the dots in the annotation key.
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
    # Target pods by their VPC IP address directly,
    # rather than routing through NodePort.
    # More efficient — one less hop in the traffic path.
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = var.certificate_arn
    # Attach the ACM certificate to this ALB listener.
    # The ALB terminates SSL here — Grafana pods receive plain HTTP.
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
    # ALB listens on both ports.
    # HTTP → HTTPS redirect is configured in the next annotation.
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    # Automatically redirect all HTTP traffic to HTTPS.
    # Users who visit http://grafana.engrshakacloud.online are
    # redirected to https://grafana.engrshakacloud.online.
  }

  # ── PRE-INSTALLED DASHBOARDS ──────────────
  # Grafana dashboard IDs from grafana.com/dashboards.
  # These are automatically imported on first startup.

  set {
    name  = "grafana.dashboardProviders.dashboardproviders\\.yaml.apiVersion"
    value = "1"
  }

  # Kubernetes cluster overview — nodes, pods, CPU, memory
  set {
    name  = "grafana.dashboards.default.kubernetes-cluster.gnetId"
    value = "7249"
    # Dashboard ID 7249 = Kubernetes Cluster Overview by Grafana Labs.
    # Shows: node CPU/memory usage, pod count, network I/O.
  }

  # Node exporter full — detailed OS-level metrics per node
  set {
    name  = "grafana.dashboards.default.node-exporter.gnetId"
    value = "1860"
    # Dashboard ID 1860 = Node Exporter Full.
    # Shows: CPU usage per core, disk I/O, memory breakdown,
    # network throughput, file descriptor usage.
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.metrics_server,
  ]
}
