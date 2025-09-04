output "certificate" {
  value = aws_acm_certificate.this
}

output "alb_alias" {
  value = aws_route53_record.alb_alias
}

output "domain_name" {
  value = aws_route53_zone.this.name
}

output "zone_id" {
  value = aws_route53_zone.this.zone_id
}
