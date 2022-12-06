# Curity Identity Server Configuration
provider "helm" {
  kubernetes {
    host                   = var.host
    cluster_ca_certificate = var.cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_id]
      command     = "aws"
    }
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
    "idsvr-cluster-config.xml" = file("${path.cwd}/../idsvr-config/idsvr-cluster-config.xml")
    "license.json"             = file("${path.cwd}/../idsvr-config/license.json")
  }
}


resource "kubernetes_secret_v1" "curity_example_eks_tls" {
  metadata {
    name      = "example-eks-tls"
    namespace = kubernetes_namespace.curity_ns.metadata.0.name
  }
  data = {
    "tls.crt" = file("${path.cwd}/../certs/example.eks.ssl.pem")
    "tls.key" = file("${path.cwd}/../certs/example.eks.ssl.key")
  }

  type = "kubernetes.io/tls"
}


resource "helm_release" "curity_idsvr" {
  name = "curity"

  repository = "https://curityio.github.io/idsvr-helm/"
  chart      = "idsvr"
  namespace  = kubernetes_namespace.curity_ns.metadata.0.name

  values = [
    file("${path.cwd}/../idsvr-config/helm-values.yaml")
  ]

}


