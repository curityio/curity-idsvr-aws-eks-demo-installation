# VPC Input Variables

variable "aws_profile_name" {
  description = "AWS profile Name"
  type        = string
}


variable "aws_region" {
  description = "AWS region to create VPC"
  type        = string
}


variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type        = string
}


variable "vpc_availability_zones" {
  description = "VPC Availability Zones"
  type        = list(string)
}


variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type        = list(string)
}


variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type        = list(string)
}


variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type        = bool
  default     = true
}


variable "common_tags" {
  description = "tags"
  type        = map(string)
}

# EKS Cluster Input Variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "version of the EKS cluster"
  type        = string
}

variable "eks_node_group_name" {
  description = "Name of the EKS node group"
  type        = string
}

variable "eks_node_instance_type" {
  description = "Instance type of the EKS node"
  type        = list(string)
}

variable "eks_node_disk_size" {
  description = "Disk size of the EKS node"
  type        = number

}

variable "eks_node_group_min_size" {
  description = "Minimum number of the EC2 instances in the EKS node group"
  type        = number

}


variable "eks_node_group_max_size" {
  description = "Maximum number of the EC2 instances in the EKS node group"
  type        = number

}

variable "eks_node_group_desired_size" {
  description = "Desired number of the EC2 instances in the EKS node group"
  type        = number

}


# Idsvr Deployment Input Variables
variable "idsvr_namespace" {
  description = "Name of the k8s namespace to deploy Curity Identity Server"
  type        = string
}


# Example API variables
variable "api_namespace" {
  description = "Name of the k8s namespace to deploy example api"
  type        = string
}

# NGINX Ingress variables
variable "ingress_controller_namespace" {
  description = "Name of the k8s namespace to deploy NGINX Ingress Controller"
  type        = string
}
