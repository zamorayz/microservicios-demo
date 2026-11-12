# Online Boutique: actualizaciones y despliegues con más control

**Proyecto Integrador DevOps** · Ángel Gabriel Zamora Vázquez

Online Boutique es una tienda de demostración donde las personas pueden consultar productos, usar un carrito y completar una compra. Está compuesta por **11 microservicios y 5 lenguajes**. Este proyecto integra herramientas DevOps para configurar el entorno, proteger credenciales y automatizar la construcción y el despliegue.

> **Fase III:** configuración de Vault con Ansible e integración con GitHub Actions para entregar credenciales de Docker Hub al pipeline con permisos limitados.

## El problema

La aplicación tiene varios microservicios que se comunican entre sí. Probar y desplegar cambios manualmente puede tomar tiempo y aumentar el riesgo de errores; además, un cambio en un servicio puede afectar a otros.

## La propuesta

Usar prácticas DevOps para agilizar el mantenimiento y realizar pruebas y despliegues más seguros y confiables. La automatización permite repetir tareas y mantener las credenciales fuera del código fuente.

## Arquitectura del flujo

~~~mermaid
flowchart LR
    Push([Push a main]) --> Repo[Repositorio en GitHub]
    Repo --> Build([GitHub Actions construye imágenes])

    Build --> Request([Solicita credenciales])
    Request --> Vault[Vault en AWS EC2]
    Vault --> Authorized([Entrega credenciales autorizadas])
    Authorized --> Build

    Build --> Publish([Publica imágenes])
    Publish --> Hub[Docker Hub]

    Build --> Deploy([Despliegue])
    Deploy --> Runner([Runner en mi máquina])
    Runner --> Helm([Ejecuta Helm])
    Helm --> Kind([Clúster Kubernetes<br/>Kind en Docker Desktop])
    Kind --> App[Online Boutique app desplegada]

    classDef action fill:#d9eaff,stroke:#68758a,color:#222;
    classDef process fill:#f2f0ff,stroke:#68758a,color:#222;
    classDef service fill:#e8f2ff,stroke:#68758a,color:#222;
    classDef result fill:#fff4dc,stroke:#68758a,color:#222;
    class Push,Repo action;
    class Build,Request,Authorized,Publish,Deploy,Runner,Helm process;
    class Vault,Hub,Kind service;
    class App result;
~~~

El push a main inicia el pipeline. GitHub Actions consulta Vault en la EC2 para obtener las credenciales autorizadas y publica las imágenes en Docker Hub. Cuando termina la construcción, el trabajo de despliegue se ejecuta en el runner de la máquina, usa Helm y actualiza la aplicación en el clúster Kind de Docker Desktop.

## Tecnologías usadas

| Tecnología | Uso |
|---|---|
| Terraform | Actualizar datos de conexión relacionados con la dirección pública vigente de EC2. |
| AWS EC2 / Ubuntu | Alojar Vault. |
| Ansible | Configurar Vault mediante el playbook **instalar-vault.yml**. |
| HashiCorp Vault | Almacenar secretos en KV y controlar el acceso mediante políticas y tokens. |
| GitHub Actions | Obtener credenciales, construir imágenes y completar el despliegue. |
| Runner self-hosted | Ejecutar los trabajos desde la máquina local conectada al proyecto. |
| Docker / Docker Desktop | Proveer el entorno local para contenedores y Kind. |
| Docker Hub | Recibir las imágenes construidas por el pipeline. |
| Kubernetes / Kind / kubectl | Ejecutar y revisar los pods de la aplicación. |
| Helm | Gestionar el despliegue en Kubernetes. |

## Cómo funciona

1. Ansible se conecta a EC2 y configura Vault.
2. Vault queda inicializado y desellado, con el motor KV habilitado.
3. La política **ci-readonly** limita los permisos del token de CI.
4. GitHub Actions se conecta a Vault mediante **VAULT_ADDR** y **VAULT_TOKEN**.
5. El pipeline lee credenciales de Docker Hub sin imprimir sus valores.
6. Los trabajos construyen y publican imágenes y completan el despliegue.
7. Kubernetes permite revisar los pods con **kubectl**.

## Infraestructura, configuración y secretos

Vault corre en una instancia EC2 con Ubuntu. Su dirección pública vigente se reflejó en **VAULT_ADDR** y en el inventario de Ansible. El playbook **instalar-vault.yml** configuró el servidor: Ansible respondió **SUCCESS** a la prueba de conexión y una segunda ejecución reportó **changed=0**.

Vault usó el motor KV para guardar las credenciales de Docker Hub. La política **ci-readonly** permitió la lectura autorizada y rechazó una escritura con **403 Permission denied**.

En GitHub Actions, **VAULT_ADDR** se guarda como variable y **VAULT_TOKEN** como secreto. No publiques tokens, contraseñas, llaves de unseal, llaves SSH, archivos .env ni valores secretos. El token administrativo no debe usarse en el pipeline.

## Pipeline CI/CD

GitHub Actions obtuvo credenciales desde Vault, construyó imágenes y las publicó en Docker Hub. La evidencia de Fase III muestra **12 trabajos completados** y el despliegue marcado como terminado.

Agrega el nombre exacto del workflow, su ruta dentro de **.github/workflows/** y las etiquetas de imagen si vas a documentar comandos específicos.


## Archivos clave: qué hacen y por qué existen

Los fragmentos siguientes muestran solo las líneas importantes de cada archivo.

### Terraform — terraform_aws/main.tf

**Qué hace:** consulta la instancia EC2 de Vault existente y devuelve su IP pública actual.

~~~hcl
data "aws_instance" "vault" {
  instance_id = var.vault_instance_id
}
output "vault_public_ip" {
  value = data.aws_instance.vault.public_ip
}
~~~

**Por qué existe:** permite actualizar la conexión de Ansible y VAULT_ADDR si cambia la IP.  
**Sin este archivo:** habría que buscar y copiar la IP manualmente, con el riesgo de usar una dirección desactualizada. Este archivo consulta EC2; no crea ni destruye la instancia.

### GitHub Actions — .github/workflows/ci-build.yml

**Qué hace:** cuando hay un push a main, el pipeline recupera las credenciales de Docker Hub desde Vault y las usa para construir y publicar imágenes. Luego despliega con Helm desde el runner self-hosted.

~~~yaml
- name: Recuperar credenciales Docker desde Vault
  uses: hashicorp/vault-action@v4
  with:
    secrets: |
      secret/data/online-boutique/dockerhub username | DOCKERHUB_USERNAME
      secret/data/online-boutique/dockerhub token | DOCKERHUB_TOKEN
~~~

~~~yaml
deploy:
  needs: build-and-push
  runs-on: self-hosted
  steps:
    - name: Deploy con Helm
      run: helm upgrade --install online-boutique ./helm-chart
~~~

**Por qué existe:** automatiza la construcción, publicación y despliegue. El workflow obtiene los secretos de Vault durante la ejecución; no guarda las credenciales de Docker Hub directamente en el YAML.  
**Sin este archivo:** el build, el push de imágenes y el despliegue serían manuales, y no habría esta conexión automatizada entre GitHub Actions y Vault.

### Ansible — ansible-lab/instalar-vault.yml

**Qué hace:** instala Vault en Ubuntu y deja el servicio habilitado e iniciado.

~~~yaml
- name: Instalar Vault
  ansible.builtin.apt:
    name: vault
    state: present

- name: Habilitar e iniciar el servicio
  ansible.builtin.systemd:
    name: vault
    enabled: true
    state: started
~~~

**Por qué existe:** describe una configuración repetible para EC2. La segunda ejecución con changed=0 confirmó que Ansible no necesitó volver a cambiar el estado.  
**Sin este archivo:** habría que instalar y configurar Vault a mano, repitiendo pasos en la instancia y aumentando la posibilidad de diferencias o errores.

### Vault — ansible-lab/politicas/ci-readonly.hcl

**Qué hace:** da permiso de lectura a la ruta de secretos de Online Boutique en KV v2.

~~~hcl
path "secret/data/online-boutique/*" {
  capabilities = ["read"]
}
~~~

**Por qué existe:** el token de CI solo necesita leer las credenciales de Docker Hub. La prueba de escritura rechazada con 403 Permission denied confirmó que ese token no podía escribir en la ruta.  
**Sin esta política:** el token de CI no tendría esta regla de lectura y Vault podría negar el acceso que necesita el pipeline. No debe sustituirse por un token administrativo.


## Cómo levantar y reproducir el proyecto

### Requisitos

- Git, Docker Desktop, Kind, kubectl y Helm.
- Terraform y Ansible en el entorno usado para administrar EC2.
- Cuenta de AWS con una instancia Ubuntu.
- Vault CLI y acceso autorizado a Vault.
- Runner self-hosted conectado al repositorio.

### Pasos generales

1. Clona el repositorio:

   ~~~bash
   git clone https://github.com/zamorayz/microservicios-demo.git
   cd microservicios-demo
   ~~~

2. Inicia Docker Desktop y comprueba que Docker esté disponible.
3. Actualiza la dirección vigente de EC2 en el inventario de Ansible y en **VAULT_ADDR**.
4. Ejecuta la prueba de conexión y **instalar-vault.yml** con las rutas reales de tu inventario.
5. Verifica que Vault esté desellado, que KV esté habilitado y que la política **ci-readonly** tenga los permisos esperados.
6. Configura **VAULT_ADDR** como variable de Actions y **VAULT_TOKEN** como secreto. Usa un token de CI de privilegios mínimos.
7. Comprueba que el runner self-hosted esté conectado y ejecuta el workflow desde **Actions**.
8. Revisa los resultados de los trabajos y las imágenes publicadas en Docker Hub.
9. Comprueba los pods:

   ~~~bash
   kubectl get pods -A
   ~~~

Las rutas de los archivos clave se indican arriba. Completa los comandos de Ansible y Terraform con los nombres del inventario y las variables de tu entorno, que pueden variar entre instalaciones.

## Resultados

- Conexión de Ansible a EC2: **SUCCESS**.
- Segunda ejecución de **instalar-vault.yml**: **changed=0**.
- Vault: inicializado, desellado y con KV habilitado.
- Permisos de CI: intento de escritura rechazado con **403 Permission denied**.
- GitHub Actions leyó credenciales de Docker Hub sin mostrar sus valores.
- Los **12 trabajos** terminaron y el despliegue quedó marcado como completado.

Las evidencias no incluyen una comparación de tiempos manuales contra automatizados. Si tienes esa medición, agrégala con la captura o fuente correspondiente.

## Retos y lecciones aprendidas

- Mantener actualizada la IP pública de EC2 en la configuración.
- Verificar conectividad antes de ejecutar la automatización.
- Usar la idempotencia de Ansible para comprobar que la configuración ya está aplicada.
- Limitar los permisos del token de CI y proteger los valores secretos.
- Respaldar cada resultado con una evidencia.

## Autor

**Ángel Gabriel Zamora Vázquez** · Proyecto Integrador DevOps  
Repositorio: [zamorayz/microservicios-demo](https://github.com/zamorayz/microservicios-demo)
