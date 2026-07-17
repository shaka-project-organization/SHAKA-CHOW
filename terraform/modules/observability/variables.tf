# terraform/modules/observability/variables.tf
variable "grafana_admin_password"    { 
  type = string
  sensitive = true 
}
variable "grafana_hostname"          { type = string }
variable "prometheus_retention_days" { type = number }
variable "certificate_arn"           { type = string }
variable "environment"               { type = string }
