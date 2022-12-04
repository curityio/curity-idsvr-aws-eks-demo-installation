# Example API variables

variable "api_namespace" {
  description = "Name of the k8s namespace to deploy example api"
  type        = string
}

variable "host" {
  description = "The Kubernetes cluster server host"
  type        = string
}

variable "cluster_id" {
  description = "Kubernetes cluster Id"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64 encoded public CA certificate used as the root of trust for the Kubernetes cluster"
  type        = string
}