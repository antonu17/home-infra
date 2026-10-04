provider "vault" {
  address = var.vault_address
  token   = var.vault_token
  # Verify HTTPS using the system trust store; never disable TLS verification.
}
