output "dependency_provider_api" {
# The value is not important because we're just using this for creating dependencies
  value = kubectl_manifest.example_api_ingress_rules_deployment.name
}