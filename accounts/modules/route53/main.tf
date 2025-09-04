resource "aws_route53_record" "alb_alias" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "api.${var.env}.originaldomain"
  type    = "CNAME"
  ttl     = 300
  records = [var.lb.dns_name]
}

resource "aws_route53_zone" "this" {
  name = "${var.env}.originaldomain"

  tags = {
    Terraform = "true"
  }
}

resource "aws_acm_certificate" "this" {
  domain_name               = "${var.env}.originaldomain"
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.env}.originaldomain"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_route53_record" "validation_record" {
  for_each = { for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => dvo }

  allow_overwrite = true
  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 300
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}
