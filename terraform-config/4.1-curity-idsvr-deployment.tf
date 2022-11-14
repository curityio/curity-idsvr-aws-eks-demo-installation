# Curity Identity Server Configuration

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
      command     = "aws"
    }
  }

}

provider "kubernetes" {
      host                   = module.eks.cluster_endpoint
      cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)  
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
          command     = "aws"
        }
}



# 
resource "kubernetes_namespace" "curity_ns" {
  metadata {
    name = var.idsvr_namespace
  }
}


resource "kubernetes_secret_v1" "idsvr_config" {
  metadata {
    name      = "idsvr-config"
    namespace = kubernetes_namespace.curity_ns.metadata.0.name
  }
  data = {
    "idsvr-cluster-config.xml" = file("${path.module}/../idsvr-config/idsvr-cluster-config.xml")
    "license.json"             = file("${path.module}/../idsvr-config/license.json")
  }
}


resource "kubernetes_secret_v1" "curity-example-eks-tls" {
  metadata {
    name      = "example-eks-tls"
    namespace = kubernetes_namespace.curity_ns.metadata.0.name
  }
  data = {
    "tls.crt" = file("${path.module}/../certs/example.eks.ssl.pem")
    "tls.key" = file("${path.module}/../certs/example.eks.ssl.key")
  }

  type = "kubernetes.io/tls"
}


resource "helm_release" "curity_idsvr" {
  name = "curity"

  repository = "https://curityio.github.io/idsvr-helm/"
  chart      = "idsvr"
  namespace  = kubernetes_namespace.curity_ns.metadata.0.name

  values = [
    file("${path.module}/../idsvr-config/helm-values.yaml")
  ]

  depends_on = [
    module.eks
  ]
}


# NGINX IC Deployment
resource "kubernetes_namespace" "ingress_ns" {
  metadata {
    name = var.ingress_controller_namespace
  }
}


resource "helm_release" "ingress-nginx" {
  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_ns.metadata.0.name

  values = [
    file("${path.module}/../ingress-nginx-config/helm-values.yaml")
  ]

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = aws_acm_certificate.this.arn
    type  = "string"
  }

  depends_on = [
    helm_release.curity_idsvr,
    kubectl_manifest.simple_api_ingress_rules_deployment
  ]

}
