# terraform/modules/dns-and-cert/variables.tf
variable "domain_name"       { type = string }
variable "app_subdomain"     { type = string }
variable "grafana_subdomain" { type = string }
variable "environment"       { type = string }
