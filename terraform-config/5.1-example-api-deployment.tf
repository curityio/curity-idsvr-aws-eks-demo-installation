# Example API Deployment Configuration

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
    command     = "aws"
  }
}


resource "kubernetes_namespace" "api_ns" {
  metadata {
    name = var.api_namespace
  }
}


resource "kubernetes_secret_v1" "api-example-eks-tls" {
  metadata {
    name      = "example-eks-tls"
    namespace = kubernetes_namespace.api_ns.metadata.0.name
  }
  data = {
    "tls.crt" = file("${path.module}/../certs/example.eks.ssl.pem")
    "tls.key" = file("${path.module}/../certs/example.eks.ssl.key")
  }

  type = "kubernetes.io/tls"
}


resource "kubectl_manifest" "simple_api_deployment" {
  yaml_body          = file("${path.module}/../example-api-config/example-api-k8s-deployment.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name
}


resource "kubectl_manifest" "simple_api_ingress_rules_deployment" {
  yaml_body          = file("${path.module}/../example-api-config/example-api-ingress-nginx.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name
}

resource "kubectl_manifest" "simple_api_svc_deployment" {
  yaml_body          = file("${path.module}/../example-api-config/example-api-k8s-service.yaml")
  override_namespace = kubernetes_namespace.api_ns.metadata.0.name

}

