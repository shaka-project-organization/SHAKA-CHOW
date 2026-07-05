# terraform/modules/dns-and-cert/outputs.tf

output "certificate_arn" {
  # Passed to the Kubernetes Ingress annotation:
  # alb.ingress.kubernetes.io/certificate-arn: <this>
  # The ALB controller reads this and attaches the cert to the HTTPS listener.
  description = "ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "zone_id" {
  # Route 53 hosted zone ID.
  # Used to create A records pointing subdomains to the ALB.
  description = "Route 53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}
