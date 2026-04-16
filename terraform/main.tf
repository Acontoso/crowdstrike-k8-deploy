resource "kubernetes_namespace" "target_namespace" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "crowdstrike_falcon_sensor" {
  name       = "crowdstrike-falcon-sensor"
  repository = "https://crowdstrike.github.io/falcon-helm"
  chart      = "falcon-sensor"
  version    = "1.35.0"
  namespace  = var.namespace

  atomic          = var.atomic
  wait            = var.wait
  timeout         = var.timeout_seconds
  cleanup_on_fail = var.cleanup_on_fail

  values = [for f in var.helm_values_files : file("${path.module}/${f}")]

  dynamic "set" {
    for_each = var.helm_set
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "node.image.repository"
    value = var.node_image_repository
  }

  set {
    name  = "node.image.digest"
    value = var.node_image_digest
  }

  set{
    name  = "node.enabled"
    value = var.node_enabled
  }

  set_sensitive {
    name  = "falcon.cid"
    value = var.falcon_cid
  }
  depends_on = [kubernetes_namespace.target_namespace]
}
