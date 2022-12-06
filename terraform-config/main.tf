module "aws_vpc" {
  source                 = "./modules/aws-vpc/"
  aws_region             = var.aws_region
  aws_profile_name       = var.aws_profile_name
  vpc_name               = var.vpc_name
  vpc_cidr_block         = var.vpc_cidr_block
  vpc_availability_zones = var.vpc_availability_zones
  vpc_private_subnets    = var.vpc_private_subnets
  vpc_public_subnets     = var.vpc_public_subnets
  cluster_name           = var.cluster_name
  common_tags            = var.common_tags

}


module "eks_cluster" {
  source                      = "./modules/eks-cluster/"
  cluster_name                = var.cluster_name
  cluster_version             = var.cluster_version
  vpc_id                      = module.aws_vpc.vpc_id
  private_subnets             = module.aws_vpc.private_subnets
  eks_node_group_name         = var.eks_node_group_name
  eks_node_instance_type      = var.eks_node_instance_type
  eks_node_disk_size          = var.eks_node_disk_size
  eks_node_group_min_size     = var.eks_node_group_min_size
  eks_node_group_max_size     = var.eks_node_group_max_size
  eks_node_group_desired_size = var.eks_node_group_desired_size

}


module "curity_idsvr" {
  source                 = "./modules/curity-idsvr/"
  idsvr_namespace        = var.idsvr_namespace
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  cluster_id             = module.eks_cluster.cluster_id

}


module "example_api" {
  source                 = "./modules/example-api/"
  api_namespace          = var.api_namespace
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  cluster_id             = module.eks_cluster.cluster_id

}


module "ingress_nginx" {
  source                       = "./modules/ingress-nginx/"
  ingress_controller_namespace = var.ingress_controller_namespace
  host                         = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate       = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  cluster_id                   = module.eks_cluster.cluster_id
  acm_cert_arn                 = module.aws_vpc.acm_certificate_arn
  ingress_nginx_depends_on_1   = module.curity_idsvr.dependency_provider_curity
  ingress_nginx_depends_on_2   = module.example_api.dependency_provider_api

}
