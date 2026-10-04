variable "vault_address" {
  description = "Verified HTTPS endpoint of the NAS-hosted Vault."
  type        = string
  validation {
    condition     = can(regex("^https://[^/]+/?$", var.vault_address))
    error_message = "vault_address must be an HTTPS origin without a path."
  }
}

variable "vault_token" {
  description = "Provisioning token; only Terraform receives this, never ESO."
  type        = string
  sensitive   = true
  validation {
    condition     = length(trimspace(var.vault_token)) > 0
    error_message = "Set TF_VAR_vault_token through the project .envrc."
  }
}

variable "kubernetes_host" {
  description = "Kubernetes API endpoint reachable from the NAS, including port 6443."
  type        = string
  validation {
    condition     = can(regex("^https://[^/]+/?$", var.kubernetes_host))
    error_message = "kubernetes_host must be an HTTPS origin."
  }
}

variable "kubernetes_ca_cert" {
  description = "PEM CA used by Vault to verify the Kubernetes API certificate."
  type        = string
  sensitive   = true
  validation {
    condition     = strcontains(var.kubernetes_ca_cert, "-----BEGIN CERTIFICATE-----")
    error_message = "Supply the Kubernetes API CA as PEM through TF_VAR_kubernetes_ca_cert."
  }
}

variable "kubernetes_token_reviewer_jwt" {
  description = "Dedicated reviewer service-account JWT with TokenReview permission; rotate before expiry."
  type        = string
  sensitive   = true
  validation {
    condition     = length(split(".", trimspace(var.kubernetes_token_reviewer_jwt))) == 3
    error_message = "Supply the reviewer JWT through TF_VAR_kubernetes_token_reviewer_jwt."
  }
}

variable "kv_mount_path" {
  description = "Dedicated KV v2 mount for home-cloud secrets. Changing this is a data migration."
  type        = string
  default     = "home-cloud"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.kv_mount_path))
    error_message = "Use a single lowercase path segment without wildcards."
  }
}

variable "kubernetes_auth_path" {
  description = "Dedicated Kubernetes auth mount for the home-cloud cluster."
  type        = string
  default     = "kubernetes-home-cloud"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.kubernetes_auth_path))
    error_message = "Use a single lowercase path segment without wildcards."
  }
}

variable "eso_roles" {
  description = "One role per workload identity; prefixes are relative to the KV mount."
  type = map(object({
    namespace       = string
    service_account = string
    secret_prefix   = string
  }))
  default = {
    cert-manager = {
      namespace       = "cert-manager"
      service_account = "vault-eso"
      secret_prefix   = "cert-manager"
    }
    external-dns = {
      namespace       = "external-dns"
      service_account = "vault-eso"
      secret_prefix   = "external-dns"
    }
    synology-csi = {
      namespace       = "synology-csi"
      service_account = "vault-eso"
      secret_prefix   = "synology-csi"
    }
    home-assistant = {
      namespace       = "home-assistant"
      service_account = "vault-eso"
      secret_prefix   = "home-assistant"
    }
  }
  validation {
    condition = alltrue([
      for name, role in var.eso_roles :
      can(regex("^[a-z0-9][a-z0-9-]*$", name)) &&
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", role.namespace)) &&
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", role.service_account)) &&
      can(regex("^[a-z0-9][a-z0-9_-]*(/[a-z0-9][a-z0-9_-]*)*$", role.secret_prefix))
    ])
    error_message = "Use explicit namespace/account names and prefixes without wildcards, dots, or empty segments."
  }
}
