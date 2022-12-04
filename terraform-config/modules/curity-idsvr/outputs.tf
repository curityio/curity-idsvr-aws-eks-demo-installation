output "dependency_provider_curity" {
# The value is not important because we're just using this for creating dependencies
  value = helm_release.curity_idsvr.name
}