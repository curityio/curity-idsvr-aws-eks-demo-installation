# EKS cluster configuration

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "18.30.0"
  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    # attach_cluster_primary_security_group = true
    create_security_group = false

  }

  eks_managed_node_groups = {
    one = {
      name           = var.eks_node_group_name
      instance_types = var.eks_node_instance_type
      disk_size      = var.eks_node_disk_size
      min_size       = var.eks_node_group_min_size
      max_size       = var.eks_node_group_max_size
      desired_size   = var.eks_node_group_desired_size
    }

  }

}
