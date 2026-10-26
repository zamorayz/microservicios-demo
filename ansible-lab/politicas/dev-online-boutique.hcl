# El desarrollador puede leer y cambiar, pero no borrar secretos de Online Boutique.
path "secret/data/online-boutique/*" {
  capabilities = ["create", "read", "update"]
}
