# VPC Configuration 
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile_name
}

# Uploads self signed certificates to ACM
resource "aws_acm_certificate" "this" {
  private_key       = file("${path.cwd}/../certs/example.eks.ssl.key")
  certificate_body  = file("${path.cwd}/../certs/example.eks.ssl.pem")
  certificate_chain = file("${path.cwd}/../certs/example.eks.ca.pem")
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.16.0"

  name = var.vpc_name
  cidr = var.vpc_cidr_block

  azs             = var.vpc_availability_zones
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared" 
    "kubernetes.io/role/elb"               = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"      = 1
  }

  tags = var.common_tags

}