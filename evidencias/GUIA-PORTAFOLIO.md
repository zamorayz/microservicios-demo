# Evidencias de Fase III

Usa capturas auténticas del Learner Lab, EC2, GitHub y Docker Hub. Explica cada imagen en 1–2 renglones. Antes de entregar, oculta IDs/valores de tokens, llaves unseal, contraseñas, llave SSH y credenciales. No publiques secretos en el repo.

## 1. Aprovisionamiento con Ansible — 25 puntos

- `terraform -chdir=terraform_aws apply -refresh-only` mostrando la IP pública actual. Este data source consulta la instancia existente; no la crea ni la destruye.
- `ansible all -i inventario-aws.ini -m ping` con `SUCCESS`.
- Primera ejecución de `ansible-playbook -i inventario-aws.ini instalar-vault.yml`, mostrando handler y cambios.
- Segunda ejecución con `changed=0` para evidenciar idempotencia.

## 2. Vault — 25 puntos

- `vault status` con `Sealed false` y `vault secrets list` mostrando `secret/` KV v2.
- `vault policy list` con `admin`, `ci-readonly` y `dev-online-boutique`.
- `vault token lookup` del token CI con su campo `id` totalmente tapado.
- Lectura permitida con CI y 403 al intentar escribir o leer otra ruta.

## 3. UI — 25 puntos

- `http://IP_PUBLICA:8200/ui` con la IP visible. Captura de acceso autorizado con token admin sin mostrar el valor secreto.
- Nueva sesión con token CI y acceso a la ruta autorizada; nunca mostrar el token.

## 4. Pipeline y documentación — 25 puntos

- Workflow manual `Leer secretos de Vault` verde, con `Login Succeeded`.
- CI completo verde: 12 builds, runner self-hosted y deploy Helm.
- Docker Hub mostrando las 12 imágenes recién publicadas.
- Actions > Secrets mostrando solo `VAULT_TOKEN`; `VAULT_ADDR` debe estar en Variables.

Cada captura necesita 1–2 renglones que expliquen qué se ve y por qué importa. No afirmes resultados que no hayas capturado.

## Configuración y operación

- Configura `VAULT_ADDR` como repository variable (por ejemplo `http://IP_PUBLICA:8200`) y `VAULT_TOKEN` como único repository secret.
- Cuando las corridas desde Vault estén verdes, borra `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` de GitHub Secrets.
- Al cambiar la IP pública de EC2, actualiza inventario y `VAULT_ADDR`.
- Si Ansible cambia `vault.hcl`, reinicia Vault; después hay que hacer unseal con las dos llaves.
- En Security Group limita 8200 a la red/IP del laboratorio y 22 a tu IP.
- `terraform_aws` consulta la instancia existente. Copia `terraform.tfvars.example` a `terraform.tfvars` y completa región/ID localmente; no subas `terraform.tfvars`.
- No subas `vault-llaves.txt`, `.bak`, llaves SSH, `~/.aws/credentials`, `.tfstate` ni tokens.
