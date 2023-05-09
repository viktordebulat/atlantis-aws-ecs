data "aws_acm_certificate" "existing_certificate" {
  domain      = "*.${var.project.domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_acm_certificate" "new_certificate" {
  count             = data.aws_acm_certificate.existing_certificate.arn == 0 ? 1 : 0
  domain_name       = "atlantis.${var.project.domain}"
  validation_method = "DNS"
}

data "aws_acm_certificate" "new_certificate" {
  count       = aws_acm_certificate.new_certificate[0].arn > 0 ? 1 : 0
  domain_name = "atlantis.${var.project.domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_route53_record" "acm_certificate_validation" {
  for_each = (
    data.aws_acm_certificate.new_certificate[0].arn > 0 ? {
      for dvo in aws_acm_certificate.new_certificate[0].domain_validation_options : dvo.domain_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    } : {}
  )

  allow_overwrite = false
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.name
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  count           = data.aws_acm_certificate.new_certificate[0].arn > 0 ? 1 : 0
  certificate_arn = aws_acm_certificate.new_certificate[0].arn

  validation_record_fqdns = [
    aws_route53_record.acm_certificate_validation[0].fqdn
  ]
}
