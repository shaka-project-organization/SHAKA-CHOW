# terraform/modules/observability/outputs.tf
output "prometheus_namespace" {
  description = "Namespace where Prometheus is deployed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "https://${var.grafana_hostname}"
}
