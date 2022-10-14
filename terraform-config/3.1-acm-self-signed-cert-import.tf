# Uploads self signed certificates to ACM

resource "aws_acm_certificate" "this" {
  private_key       = file("${path.module}/../certs/example.eks.ssl.key")
  certificate_body  = file("${path.module}/../certs/example.eks.ssl.pem")
  certificate_chain = file("${path.module}/../certs/example.eks.ca.pem")
}
