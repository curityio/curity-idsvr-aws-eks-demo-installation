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

variable "cluster_name" {
  description = "EKS cluster name"
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


