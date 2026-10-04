# Synthetic credentials and a mocked provider: these tests never contact Vault.
mock_provider "vault" {}

variables {
  vault_address                 = "https://vault.example.test"
  vault_token                   = "synthetic-test-token"
  kubernetes_host               = "https://kubernetes.example.test:6443"
  kubernetes_ca_cert            = "-----BEGIN CERTIFICATE-----\nsynthetic-test-ca\n-----END CERTIFICATE-----"
  kubernetes_token_reviewer_jwt = "synthetic.reviewer.jwt"
}

run "default_workload_scope" {
  command = plan

  assert {
    condition     = vault_mount.home_cloud.options["version"] == "2"
    error_message = "The secrets mount must use KV v2."
  }
  assert {
    condition     = vault_kubernetes_auth_backend_config.home_cloud.disable_local_ca_jwt
    error_message = "NAS-hosted Vault must use the explicitly supplied Kubernetes credentials."
  }
  assert {
    condition = (
      vault_kubernetes_auth_backend_role.eso["home-assistant"].bound_service_account_names == toset(["vault-eso"]) &&
      vault_kubernetes_auth_backend_role.eso["home-assistant"].bound_service_account_namespaces == toset(["home-assistant"]) &&
      vault_kubernetes_auth_backend_role.eso["home-assistant"].audience == "vault" &&
      vault_kubernetes_auth_backend_role.eso["home-assistant"].token_no_default_policy
    )
    error_message = "ESO identity must be namespace/account-bound, audience-bound, and omit the default policy."
  }
  assert {
    condition = (
      vault_kubernetes_auth_backend_role.eso["cert-manager"].bound_service_account_names == toset(["vault-eso"]) &&
      vault_kubernetes_auth_backend_role.eso["cert-manager"].bound_service_account_namespaces == toset(["cert-manager"]) &&
      vault_kubernetes_auth_backend_role.eso["cert-manager"].audience == "vault" &&
      vault_kubernetes_auth_backend_role.eso["cert-manager"].token_policies == toset(["eso-cert-manager"]) &&
      vault_kubernetes_auth_backend_role.eso["cert-manager"].token_no_default_policy &&
      strcontains(vault_policy.eso["cert-manager"].policy, "home-cloud/data/cert-manager/*") &&
      !strcontains(vault_policy.eso["cert-manager"].policy, "home-cloud/data/home-assistant") &&
      !strcontains(vault_policy.eso["home-assistant"].policy, "home-cloud/data/cert-manager")
    )
    error_message = "cert-manager must have its own namespace-bound identity and isolated read policy."
  }
  assert {
    condition = (
      strcontains(vault_policy.eso["home-assistant"].policy, "home-cloud/data/home-assistant/*") &&
      !strcontains(vault_policy.eso["home-assistant"].policy, "home-cloud/data/*") &&
      !strcontains(vault_policy.eso["home-assistant"].policy, "\"create\"") &&
      !strcontains(vault_policy.eso["home-assistant"].policy, "\"delete\"")
    )
    error_message = "ESO must not read the entire mount or write/delete secret values."
  }
}

run "separate_workload_policies" {
  command = plan
  variables {
    eso_roles = {
      home-assistant = {
        namespace       = "home-assistant"
        service_account = "vault-eso"
        secret_prefix   = "home-assistant"
      }
      monitoring = {
        namespace       = "monitoring"
        service_account = "vault-eso"
        secret_prefix   = "monitoring"
      }
    }
  }
  assert {
    condition = (
      !strcontains(vault_policy.eso["home-assistant"].policy, "monitoring") &&
      !strcontains(vault_policy.eso["monitoring"].policy, "home-assistant") &&
      vault_kubernetes_auth_backend_role.eso["monitoring"].token_policies == toset(["eso-monitoring"])
    )
    error_message = "Each workload must receive only its own policy and prefix."
  }
}

run "reject_wildcard_identity" {
  command = plan
  variables {
    eso_roles = {
      broad = {
        namespace       = "*"
        service_account = "vault-eso"
        secret_prefix   = "*"
      }
    }
  }
  expect_failures = [var.eso_roles]
}
