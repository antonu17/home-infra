ui = true
# Raft uses memory-mapped files. Disable NAS swap before use (see README).
disable_mlock = true
api_addr = "https://vault.home.antonu.org"
cluster_addr = "http://vault:8201"

storage "raft" {
  path = "/vault/storage/data"
  node_id = "synology-vault-01"
}

# HTTP is confined to the project network and NAS loopback; DSM terminates TLS.
listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = true
}
