output "ses_domain" {
  value = aws_ses_domain_mail_from.this.mail_from_domain
}

output "ses_arn" {
  value = aws_ses_domain_identity.this.arn
}
