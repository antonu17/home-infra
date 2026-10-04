resource "vault_mount" "home_cloud" {
  path        = var.kv_mount_path
  type        = "kv"
  description = "Home-cloud application secrets, consumed through ESO"
  options     = { version = "2" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = var.kubernetes_auth_path
  description = "Kubernetes authentication for home-cloud ESO identities"

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_kubernetes_auth_backend_config" "home_cloud" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  kubernetes_ca_cert     = var.kubernetes_ca_cert
  token_reviewer_jwt     = var.kubernetes_token_reviewer_jwt
  disable_local_ca_jwt   = true
  disable_iss_validation = true
}

resource "vault_policy" "eso" {
  for_each = var.eso_roles
  name     = "eso-${each.key}"
  policy = templatefile("${path.module}/policies/eso-read.hcl.tftpl", {
    mount  = vault_mount.home_cloud.path
    prefix = each.value.secret_prefix
  })
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  for_each                         = var.eso_roles
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "eso-${each.key}"
  bound_service_account_names      = [each.value.service_account]
  bound_service_account_namespaces = [each.value.namespace]
  audience                         = "vault"
  alias_name_source                = "serviceaccount_uid"
  token_policies                   = [vault_policy.eso[each.key].name]
  token_no_default_policy          = true
  token_type                       = "service"
  token_ttl                        = 900
  token_max_ttl                    = 3600

  depends_on = [vault_kubernetes_auth_backend_config.home_cloud]
}
