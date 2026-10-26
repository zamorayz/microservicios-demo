terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "aws_region" {
  description = "Región de la EC2 de Vault en AWS Learner Lab."
  type        = string
}

variable "vault_instance_id" {
  description = "ID i-... de la instancia fase3-vault ya existente."
  type        = string
}

provider "aws" {
  region = var.aws_region
}

# Solo consulta la instancia existente; no crea ni destruye recursos.
data "aws_instance" "vault" {
  instance_id = var.vault_instance_id
}

output "vault_public_ip" {
  description = "IP pública actual para VAULT_ADDR y Ansible."
  value       = data.aws_instance.vault.public_ip
}
