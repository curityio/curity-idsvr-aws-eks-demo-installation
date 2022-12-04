# EKS Cluster Input Variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "version of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "private_subnets" {
  description = "private subnets"
  type        = list(string)
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
