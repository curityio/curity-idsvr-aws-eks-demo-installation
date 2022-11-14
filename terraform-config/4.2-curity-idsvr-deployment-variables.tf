# Idsvr Deployment Input Variables

variable "idsvr_namespace" {
  description = "Name of the k8s namespace to deploy Curity Identity Server"
  type        = string
}

variable "ingress_controller_namespace" {
  description = "Name of the k8s namespace to deploy NGINX Ingress Controller"
  type        = string
}