# Example API Deployment Configuration

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

provider "kubectl" {
  host                   = var.host
  cluster_ca_certificate = var.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_id]
    command     = "aws"
  }
}

provider "kubernetes" {
  host                   = var.host
  cluster_ca_certificate = var.cluster_ca_certificate
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_id]
    command     = "aws"
  }
}


resource "kubernetes_namespace" "api_ns" {
  metadata {
    name = var.api_namespace
  }
}


resource "kubernetes_secret_v1" "api_example_eks_tls" {
  metadata {
    name      = "example-eks-tls"
    namespace = kubernetes_namespace.api_ns.metadata.0.name
  }
  data = {
    "tls.crt" = file("${path.cwd}/../certs/example.eks.ssl.pem")
    "tls.key" = file("${path.cwd}/../certs/example.eks.ssl.key")
  }

  type = "kubernetes.io/tls"
}


resource "kubectl_manifest" "example_api_deployment" {
  yaml_body          = file("${path.cwd}/../example-api-config/example-api-k8s-deployment.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name
}


resource "kubectl_manifest" "example_api_ingress_rules_deployment" {
  yaml_body          = file("${path.cwd}/../example-api-config/example-api-ingress-nginx.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name
}

resource "kubectl_manifest" "example_api_svc_deployment" {
  yaml_body          = file("${path.cwd}/../example-api-config/example-api-k8s-service.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name

}
