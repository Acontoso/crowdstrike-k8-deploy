output "helm_release_name" {
  description = "Deployed Helm release name"
  value       = helm_release.crowdstrike_falcon_sidecar_container.name
}

output "helm_release_namespace" {
  description = "Namespace where release is deployed"
  value       = helm_release.crowdstrike_falcon_sidecar_container.namespace
}

output "helm_release_status" {
  description = "Release status"
  value       = helm_release.crowdstrike_falcon_sidecar_container.status
}
