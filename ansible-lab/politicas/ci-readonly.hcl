# El pipeline solo lee secretos de Online Boutique (KV v2).
path "secret/data/online-boutique/*" {
  capabilities = ["read"]
}
