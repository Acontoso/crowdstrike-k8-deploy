variable "aws_region" {
  description = "AWS region that hosts the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Target EKS cluster name"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Create namespace if it does not exist"
  type        = bool
  default     = true
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://crowdstrike.github.io/falcon-helm"
}

variable "chart_name" {
  description = "Chart name in the repository"
  type        = string
  default     = "falcon-sensor"
}

variable "chart_version" {
  description = "Optional fixed chart version (null = latest)"
  type        = string
  default     = null
}

variable "helm_values_files" {
  description = "List of values file paths relative to terraform/"
  type        = list(string)
  default     = []
}

variable "helm_set" {
  description = "Simple key/value overrides for Helm --set"
  type        = map(string)
  default     = {}
}

variable "atomic" {
  description = "Rollback automatically if upgrade/install fails"
  type        = bool
  default     = true
}

variable "wait" {
  description = "Wait until all resources are in a ready state"
  type        = bool
  default     = true
}

variable "timeout_seconds" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 600
}

variable "cleanup_on_fail" {
  description = "Delete newly-created resources when install fails"
  type        = bool
  default     = true
}

variable "falcon_cid" {
  description = "CrowdStrike Customer ID (CID)"
  type        = string
  sensitive   = true
}

variable "node_image_repository" {
  description = "Node sensor image repository (for example <ecr-registry>/falcon-sensor)"
  type        = string
}

variable "node_image_digest" {
  description = "Node sensor image digest (for example sha256:...) to deploy in chart"
  type        = string
}
