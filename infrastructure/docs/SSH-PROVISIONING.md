# Gestion du provisionnement SSH dans les modules EC2

Ce document explique comment gérer le provisionnement SSH des instances EC2 dans les environnements CI/CD.

## Problème

Lors de l'exécution de Terraform dans un environnement CI/CD (comme GitHub Actions), la fonction `file()` utilisée pour lire la clé SSH privée peut échouer car le fichier n'existe pas sur le runner. Cela provoque des erreurs comme :

```
Error: Invalid function argument

  on modules/ec2-monitoring/main.tf line 115, in resource "null_resource" "provision_monitoring":
  115:       private_key = file(var.ssh_private_key_path)
     ├────────────────
     │ while calling file(path)
     │ var.ssh_private_key_path is "~/.ssh/id_rsa"

Invalid value for "path" parameter: no file exists at "~/.ssh/id_rsa"; this
function works only with files that are distributed as part of the
configuration source code, so if this file will be created by a resource in
this configuration you must instead obtain this result from an attribute of
that resource.
```

## Solution

Nous avons mis en place deux mécanismes pour résoudre ce problème :

### 1. Provisionnement conditionnel

Le provisionnement SSH est maintenant conditionnel et désactivé par défaut dans les environnements CI/CD :

```hcl
resource "null_resource" "provision_monitoring" {
  # Ne créer cette ressource que si le provisionnement est activé
  count = var.enable_provisioning ? 1 : 0

  # ... reste du code ...
}
```

### 2. Options de clé SSH flexibles

Deux options sont maintenant disponibles pour fournir la clé SSH :

1. **Chemin du fichier** : Utilisation traditionnelle via `ssh_private_key_path`
2. **Contenu de la clé** : Fourniture directe du contenu de la clé via `ssh_private_key_content`

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  host        = aws_instance.monitoring_instance.public_ip
  private_key = var.ssh_private_key_content != "" ? var.ssh_private_key_content : file(var.ssh_private_key_path)
}
```

### 3. Instructions de configuration manuelle

Si le provisionnement automatique est désactivé, des instructions détaillées sont fournies dans les outputs Terraform pour configurer manuellement l'instance :

```
output "manual_setup_instructions" {
  description = "Instructions pour configurer manuellement l'instance EC2 de monitoring si le provisionnement automatique est désactivé"
  value       = var.enable_provisioning ? "Le provisionnement automatique est activé." : <<-EOT
Le provisionnement automatique est désactivé. Pour configurer manuellement l'instance EC2 de monitoring :

1. Connectez-vous à l'instance EC2 via SSH : ssh ec2-user@${aws_instance.monitoring_instance.public_ip}
2. Exécutez les commandes suivantes :
   ...
EOT
}
```

## Utilisation

### Dans les environnements CI/CD (GitHub Actions)

Le workflow GitHub Actions est configuré pour utiliser automatiquement la clé SSH si elle est disponible dans les secrets GitHub :

1. **Configuration de la clé SSH** :
   - Le secret `EC2_SSH_PRIVATE_KEY` est utilisé pour créer un fichier de clé SSH sur le runner
   - Le provisionnement est activé automatiquement si la clé SSH est disponible (`enable_provisioning=${{ secrets.EC2_SSH_PRIVATE_KEY != '' }}`)

2. **Secrets GitHub requis** :
   - `EC2_KEY_PAIR_NAME` : Nom de la paire de clés SSH sur AWS (par exemple, "ma-cle-ssh")
   - `EC2_SSH_PRIVATE_KEY` : Contenu de la clé SSH privée

Si ces secrets ne sont pas configurés, le provisionnement est désactivé automatiquement, ce qui permet à Terraform de s'exécuter sans erreur même si aucune clé SSH n'est disponible.

### En développement local

Pour activer le provisionnement automatique en local :

1. Assurez-vous que votre clé SSH existe à l'emplacement spécifié (`~/.ssh/id_rsa` par défaut)
2. Définissez `enable_provisioning = true` dans votre fichier `terraform.tfvars` ou via la ligne de commande :

```bash
terraform apply -var="enable_provisioning=true"
```

### Utilisation du contenu de la clé SSH

Si vous préférez fournir directement le contenu de la clé SSH (par exemple, à partir d'un secret GitHub) :

```bash
terraform apply -var="ssh_private_key_content=$(cat ~/.ssh/id_rsa)"
```

Ou dans un workflow GitHub Actions :

```yaml
terraform apply -var="ssh_private_key_content=${{ secrets.SSH_PRIVATE_KEY }}"
```

## Remarques

- Cette solution permet de déployer l'infrastructure même sans accès SSH
- Les instructions de configuration manuelle permettent de configurer les instances après le déploiement
- Pour une sécurité optimale, utilisez toujours des secrets pour stocker les clés SSH
