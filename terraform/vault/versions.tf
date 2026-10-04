terraform {
  backend "local" {}

  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.9.0"
    }
  }
}
