# Administrador de Vault para la práctica; token con TTL y revocable.
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
