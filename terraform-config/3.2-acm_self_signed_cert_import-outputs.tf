# ACM Certificate output

output "acm_certificate_arn" {
  description = "arn of acm certificate"
  value       = aws_acm_certificate.this.arn
}
