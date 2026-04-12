resource "kubernetes_namespace" "target_namespace" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "crowdstrike_falcon_sidecar_container" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = var.chart_name
  version    = var.chart_version
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
    name  = "container.image.repository"
    value = var.container_image_repository
  }

  set {
    name  = "container.image.digest"
    value = var.container_image_digest
  }

  set_sensitive {
    name  = "falcon.cid"
    value = var.falcon_cid
  }

  depends_on = [kubernetes_namespace.target_namespace]
}
