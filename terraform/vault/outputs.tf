output "kv_mount_path" {
  value = vault_mount.home_cloud.path
}

output "kubernetes_auth_path" {
  value = vault_auth_backend.kubernetes.path
}

output "eso_roles" {
  description = "Non-secret SecretStore settings for each scoped workload identity."
  value = {
    for name, role in var.eso_roles : name => {
      vault_role      = vault_kubernetes_auth_backend_role.eso[name].role_name
      namespace       = role.namespace
      service_account = role.service_account
      secret_prefix   = role.secret_prefix
      audience        = "vault"
    }
  }
}
