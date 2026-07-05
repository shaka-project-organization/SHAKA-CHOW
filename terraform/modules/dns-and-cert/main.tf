# ============================================================
# FILE: terraform/modules/dns-and-cert/main.tf
# PURPOSE: Provisions SSL/TLS certificates and DNS records.
#   1. Reads the existing Route 53 hosted zone for your domain.
#   2. Creates an ACM wildcard certificate covering:
#        *.engrshakacloud.online  (all subdomains)
#        engrshakacloud.online    (apex domain)
#   3. Creates DNS validation CNAME records in Route 53 so
#      ACM can prove you own the domain and issue the cert.
#   4. Waits for the certificate to be issued.
#   5. Creates A records: shakachow → ALB, grafana → ALB.
#      (A records are created AFTER the ALB exists — we use
#       a placeholder here and update via k8s annotations.)
# ============================================================

# ─────────────────────────────────────────────
# DATA SOURCE: Existing Route 53 Hosted Zone
# You must have already registered the domain and
# created a hosted zone in Route 53 before running
# Terraform. This reads the zone without creating it.
# ─────────────────────────────────────────────
data "aws_route53_zone" "main" {
  name         = var.domain_name
  # "engrshakacloud.online" — must match exactly.
  private_zone = false
  # private_zone = false means this is a public zone
  # resolvable from the internet, not a private VPC zone.
}

# ─────────────────────────────────────────────
# ACM CERTIFICATE
# A single wildcard certificate covers all subdomains.
# "*.engrshakacloud.online" matches:
#   shakachow.engrshakacloud.online
#   grafana.engrshakacloud.online
#   api.engrshakacloud.online
#   (any single-level subdomain)
# The Subject Alternative Name (SAN) adds the apex domain.
# ─────────────────────────────────────────────
resource "aws_acm_certificate" "main" {
  domain_name       = "*.${var.domain_name}"
  # Primary name: wildcard covers all subdomains.

  subject_alternative_names = [var.domain_name]
  # SAN: also covers the apex domain (no subdomain).

  validation_method = "DNS"
  # DNS validation = ACM gives you CNAME records to add to
  # Route 53. Once the CNAMEs are in place, ACM verifies
  # you control the domain and issues the certificate.
  # Alternative: EMAIL validation — but DNS is preferred
  # because it's automated and doesn't require inbox access.

  # lifecycle.create_before_destroy: when you need to replace
  # a certificate (e.g. adding a new domain), Terraform creates
  # the new cert first, then destroys the old one.
  # Without this, Terraform would destroy the old cert first,
  # causing an SSL outage during the replacement window.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "shakachow-cert"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────
# DNS VALIDATION RECORDS
# ACM provides CNAME records that prove domain ownership.
# We create these in Route 53 automatically so Terraform
# handles the full certificate issuance without manual steps.
# "for_each" iterates over the set of validation options
# ACM requires (one per domain name in the certificate).
# ─────────────────────────────────────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      # type is always "CNAME" for DNS validation.
    }
  }
  # The for expression builds a map keyed by domain name.
  # Each entry has the CNAME name, value, and type that
  # ACM requires for validation.

  allow_overwrite = true
  # If the validation record already exists (e.g. from a
  # previous apply), overwrite it rather than erroring.

  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  # TTL of 60 seconds — low TTL because this is temporary.
  # ACM reads the record, validates, then you can leave it
  # indefinitely (it doesn't hurt) or remove it.
  type    = each.value.type
  zone_id = data.aws_route53_zone.main.zone_id
}

# ─────────────────────────────────────────────
# CERTIFICATE VALIDATION WAITER
# Terraform waits here until ACM has verified the DNS
# records and issued the certificate. Typically takes
# 1-5 minutes. The certificate cannot be used until
# its status changes from PENDING_VALIDATION to ISSUED.
# ─────────────────────────────────────────────
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
    # fqdn = fully-qualified domain name of each validation record.
    # Terraform monitors these until ACM confirms validation.
  ]
}
