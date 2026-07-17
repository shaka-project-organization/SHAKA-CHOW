
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "prometheus.io/scrape" = "true"
    }
  }
}


resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.11.0"
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  wait    = true
  timeout = 600


  # ── PROMETHEUS CONFIGURATION ──────────────
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.prometheus_retention_days}d"

  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp2"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"

  }

  set {
    name  = "prometheus.prometheusSpec.scrapeInterval"
    value = "15s"
  }

  set {
    name  = "defaultRules.rules.kubeStateMetrics"
    value = "true"
  }

  set {
    name  = "defaultRules.rules.alertmanager"
    value = "true"
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
  }

  set {
    name  = "grafana.ingress.enabled"
    value = "true"

  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  
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
