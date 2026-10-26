# Integración Fase III en este fork

Esta carpeta es una copia local de `zamorayz/microservicios-demo` con los cambios propuestos para Fase III. El workflow de Fase II fue actualizado para pedir a Vault las credenciales de Docker Hub; también se añadieron el workflow de prueba, `ansible-lab/`, `terraform_aws/` y la guía de evidencias.

## Preparar Terraform AWS para consultar la EC2

`terraform_aws/main.tf` consulta la instancia existente mediante su ID y muestra la IP actual; no crea, modifica ni destruye la EC2. Con Learner Lab activo:

```bash
cd terraform_aws
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con la región AWS y el ID i-... de la instancia fase3-vault.
terraform init
terraform apply -refresh-only
terraform output -raw vault_public_ip
```

El `.terraform.lock.hcl` se versiona para fijar el proveedor. Nunca subas `.tfstate` ni `terraform.tfvars`.

## Aprovisionamiento Ansible

Sustituye IP y ruta SSH en `ansible-lab/inventario-aws.ini`, luego desde WSL:

```bash
cd ansible-lab
ansible all -i inventario-aws.ini -m ping
ansible-playbook -i inventario-aws.ini instalar-vault.yml
ansible-playbook -i inventario-aws.ini instalar-vault.yml
```

Si Ansible cambia la configuración y reinicia Vault, vuelve a hacer unseal con dos llaves. Las políticas se encuentran en `ansible-lab/politicas/`.

## GitHub Actions

Configura repository variable `VAULT_ADDR` con la IP pública actual y repository secret `VAULT_TOKEN` con el token CI (TTL 168h). Carga en Vault el secreto KV v2 `secret/online-boutique/dockerhub` con `username` y el token Docker Hub real. Corre primero `Leer secretos de Vault`; después confirma runner, nodo `kind` y ejecuta CI. Borra los secrets antiguos de Docker Hub cuando todo quede verde.

Revisa `evidencias/GUIA-PORTAFOLIO.md` para la lista de capturas. La carpeta de trabajo es una copia local: estos cambios no se han enviado a GitHub.
