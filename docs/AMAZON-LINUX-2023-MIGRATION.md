# Migration vers Amazon Linux 2023 - YourMédia

Ce document décrit la migration de l'infrastructure YourMédia d'Amazon Linux 2 vers Amazon Linux 2023, ainsi que les améliorations apportées à l'ordre d'exécution des scripts. Il inclut également les modifications récentes pour standardiser tous les scripts sur Amazon Linux 2023 et supprimer les scripts et workflows inutiles.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Modifications pour Amazon Linux 2023](#modifications-pour-amazon-linux-2023)
   - [Détection automatique des AMI](#détection-automatique-des-ami)
   - [Modifications des scripts](#modifications-des-scripts)
   - [Gestion des paquets avec DNF](#gestion-des-paquets-avec-dnf)
3. [Améliorations de l'ordre d'exécution des scripts](#améliorations-de-lordre-dexécution-des-scripts)
   - [Téléchargement des scripts dans S3](#téléchargement-des-scripts-dans-s3)
   - [Gestion des permissions](#gestion-des-permissions)
   - [Vérification des dépendances](#vérification-des-dépendances)
4. [Standardisation sur Amazon Linux 2023](#standardisation-sur-amazon-linux-2023)
   - [Scripts adaptés](#scripts-adaptés)
   - [Scripts supprimés](#scripts-supprimés)
   - [Workflows GitHub Actions supprimés](#workflows-github-actions-supprimés)
5. [Tests et validation](#tests-et-validation)
6. [Rollback en cas de problème](#rollback-en-cas-de-problème)

## Vue d'ensemble

Amazon Linux 2023 est la nouvelle génération d'Amazon Linux, offrant des améliorations significatives par rapport à Amazon Linux 2 :

- Mises à jour de sécurité plus fréquentes
- Versions plus récentes des paquets
- Support à long terme (5 ans)
- Meilleure compatibilité avec les applications modernes
- Performances améliorées

Cette migration permet de bénéficier de ces avantages tout en maintenant la compatibilité avec l'infrastructure existante.

## Modifications pour Amazon Linux 2023

### Détection automatique des AMI

La détection automatique des AMI Amazon Linux 2023 a été mise en place pour garantir l'utilisation des images les plus récentes :

```hcl
# Récupération automatique de l'AMI Amazon Linux 2023 la plus récente
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

Les variables Terraform ont été mises à jour pour utiliser cette détection automatique :

```hcl
variable "ami_id" {
  description = "ID de l'AMI Amazon Linux 2023 à utiliser pour l'EC2 (doit correspondre à la région)."
  type        = string
  default     = "" # Laissez vide pour utiliser l'AMI la plus récente via data source
}

variable "use_latest_ami" {
  description = "Utiliser l'AMI Amazon Linux 2023 la plus récente au lieu de l'AMI spécifiée."
  type        = bool
  default     = true
}
```

### Modifications des scripts

Les scripts d'installation et de configuration ont été mis à jour pour être compatibles avec Amazon Linux 2023 :

1. **Suppression des références à `amazon-linux-extras`** : Cette fonctionnalité n'existe plus dans Amazon Linux 2023.
2. **Mise à jour des chemins et des commandes** : Certains chemins et commandes ont changé dans Amazon Linux 2023.
3. **Adaptation des scripts d'installation** : Les scripts ont été adaptés pour utiliser les nouvelles méthodes d'installation des paquets.

### Gestion des paquets avec DNF

Amazon Linux 2023 utilise DNF comme gestionnaire de paquets au lieu de YUM. Tous les scripts ont été mis à jour pour utiliser DNF :

```bash
# Ancienne commande (Amazon Linux 2)
sudo yum update -y
sudo yum install -y package-name

# Nouvelle commande (Amazon Linux 2023)
sudo dnf update -y
sudo dnf install -y package-name
```

Les modifications incluent :
- Remplacement de `yum` par `dnf` dans tous les scripts
- Remplacement de `yum-utils` par `dnf-utils`
- Remplacement de `yum-config-manager` par `dnf config-manager`

## Améliorations de l'ordre d'exécution des scripts

### Téléchargement des scripts dans S3

Une étape explicite a été ajoutée au workflow GitHub Actions pour télécharger tous les scripts nécessaires dans le bucket S3 avant le déploiement de l'infrastructure :

```yaml
# Étape 7.5: Téléchargement des scripts dans S3 (uniquement pour l'application)
- name: Upload Scripts to S3
  id: upload_scripts
  if: github.event.inputs.action == 'apply'
  run: |
    echo "::group::Téléchargement des scripts dans S3"
    # Créer le fichier de clé SSH si le secret est disponible
    if [ ! -z "${{ secrets.EC2_SSH_PRIVATE_KEY }}" ]; then
      mkdir -p ~/.ssh
      echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      echo "Clé SSH privée configurée."
    fi

    # Exporter les variables d'environnement AWS
    export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
    export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
    export AWS_DEFAULT_REGION="${{ env.AWS_REGION }}"

    # Récupérer le nom du bucket S3 depuis les outputs Terraform
    S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

    if [ -z "$S3_BUCKET_NAME" ]; then
      echo "Aucun bucket S3 trouvé dans les outputs Terraform. Création de l'infrastructure nécessaire..."
      # Appliquer uniquement le module S3
      terraform apply -auto-approve -target=module.s3 \
        -var="aws_access_key=${{ secrets.AWS_ACCESS_KEY_ID }}" \
        -var="aws_secret_key=${{ secrets.AWS_SECRET_ACCESS_KEY }}" \
        -var="db_username=${{ secrets.DB_USERNAME }}" \
        -var="db_password=${{ secrets.DB_PASSWORD }}" \
        -var="environment=${{ github.event.inputs.environment }}"

      # Récupérer le nom du bucket S3 après la création
      S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    fi

    if [ ! -z "$S3_BUCKET_NAME" ]; then
      echo "Téléchargement des scripts dans le bucket S3: $S3_BUCKET_NAME"

      # Télécharger les scripts de monitoring
      echo "Téléchargement des scripts de monitoring..."
      aws s3 cp --recursive ./scripts/ec2-monitoring/ s3://$S3_BUCKET_NAME/scripts/ec2-monitoring/

      # Télécharger les scripts Java/Tomcat
      echo "Téléchargement des scripts Java/Tomcat..."
      aws s3 cp --recursive ./scripts/ec2-java-tomcat/ s3://$S3_BUCKET_NAME/scripts/ec2-java-tomcat/

      # Télécharger les scripts Docker
      echo "Téléchargement des scripts Docker..."
      aws s3 cp --recursive ./scripts/docker/ s3://$S3_BUCKET_NAME/scripts/docker/

      echo "Scripts téléchargés avec succès dans le bucket S3: $S3_BUCKET_NAME"
    else
      echo "ERREUR: Impossible de récupérer le nom du bucket S3. Les scripts ne seront pas téléchargés."
      exit 1
    fi
    echo "::endgroup::"
```

Cette étape garantit que tous les scripts nécessaires sont disponibles dans S3 avant le déploiement des instances EC2.

### Gestion des permissions

Le script `init-instance.sh` a été modifié pour télécharger et installer `docker-manager.sh` dans `/usr/local/bin/` :

```bash
# Téléchargement des scripts depuis S3
log "Téléchargement des scripts depuis S3"
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/setup.sh /opt/monitoring/setup.sh
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/install-docker.sh /opt/monitoring/install-docker.sh
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/fix_permissions.sh /opt/monitoring/fix_permissions.sh
sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/docker/docker-manager.sh /opt/monitoring/docker-manager.sh

# Rendre les scripts exécutables
sudo chmod +x /opt/monitoring/install-docker.sh
sudo chmod +x /opt/monitoring/setup.sh
sudo chmod +x /opt/monitoring/fix_permissions.sh
sudo chmod +x /opt/monitoring/docker-manager.sh

# Copier docker-manager.sh dans /usr/local/bin/
log "Copie de docker-manager.sh dans /usr/local/bin/"
sudo cp /opt/monitoring/docker-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-manager.sh
```

Le script `setup.sh` a été modifié pour appeler explicitement `fix_permissions.sh` à la fin de l'installation :

```bash
# Exécution du script de correction des permissions
log "Exécution du script de correction des permissions..."
if [ -f "/opt/monitoring/fix_permissions.sh" ]; then
    sudo /opt/monitoring/fix_permissions.sh
else
    log "AVERTISSEMENT: Le script fix_permissions.sh n'est pas disponible."
    # Correction manuelle des permissions
    sudo chown -R ec2-user:ec2-user /opt/monitoring
    sudo chmod -R 755 /opt/monitoring
fi
```

### Vérification des dépendances

Des fonctions de vérification des dépendances ont été ajoutées aux scripts pour s'assurer que toutes les dépendances nécessaires sont installées avant l'exécution des commandes :

```bash
# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency aws aws-cli
check_dependency curl curl
check_dependency sed sed
```

Ces vérifications garantissent que les scripts ne rencontreront pas d'erreurs dues à des dépendances manquantes.

## Standardisation sur Amazon Linux 2023

En avril 2025, tous les scripts ont été standardisés pour utiliser exclusivement Amazon Linux 2023, et les scripts et workflows inutiles ont été supprimés.

### Scripts adaptés

Les scripts suivants ont été adaptés pour fonctionner exclusivement avec Amazon Linux 2023 :

1. **`scripts/ec2-monitoring/install-docker.sh`** : Ce script a été modifié pour installer Docker spécifiquement sur Amazon Linux 2023 uniquement. Toutes les références à Amazon Linux 2 et les méthodes d'installation alternatives ont été supprimées pour simplifier le script et le rendre plus robuste.

2. **`scripts/ec2-monitoring/setup.sh`** : Ce script a été modifié pour installer Docker sur Amazon Linux 2023 uniquement, en supprimant les références à Amazon Linux 2 et en utilisant les commandes spécifiques à Amazon Linux 2023.

### Scripts supprimés

Les scripts suivants ont été supprimés car ils étaient redondants ou obsolètes :

1. **`scripts/ec2-monitoring/init-instance.sh`** : Ce script a été remplacé par `scripts/ec2-monitoring/init-instance-env.sh`, qui utilise des variables d'environnement pour une meilleure flexibilité et sécurité. Nous utilisons maintenant exclusivement `init-instance-env.sh` pour l'initialisation des instances EC2.

### Workflows GitHub Actions supprimés

Les workflows GitHub Actions suivants ont été supprimés car ils étaient inutiles, redondants ou présentaient des risques de sécurité :

1. **`view-secret-securely.yml`** : Ce workflow permettait de consulter les secrets GitHub, mais présentait un risque de sécurité car il affichait les secrets en clair dans les logs. Il a été supprimé pour améliorer la sécurité du projet.

2. **`3.1-canary-deployment.yml`** : Ce workflow complexe pour le déploiement canary semblait inutile pour un projet simple. Il a été supprimé pour simplifier le projet.

3. **`sync-secrets-to-terraform.yml`** : Ce workflow était redondant car le workflow principal `1-infra-deploy-destroy.yml` gère déjà la synchronisation des secrets avec Terraform Cloud. Il a été supprimé pour simplifier le projet.

4. **`upload-scripts-to-s3.yml`** : Ce workflow était redondant car le workflow principal `1-infra-deploy-destroy.yml` inclut déjà une étape pour télécharger les scripts dans S3. Il a été supprimé pour simplifier le projet.

## Tests et validation

Après la migration vers Amazon Linux 2023, il est recommandé de tester les points suivants :

1. **Déploiement de l'infrastructure** : Vérifier que l'infrastructure se déploie correctement avec les nouvelles AMI.
2. **Installation des applications** : Vérifier que Java, Tomcat, Docker et les autres applications s'installent correctement.
3. **Fonctionnement des applications** : Vérifier que les applications fonctionnent correctement après le déploiement.
4. **Monitoring** : Vérifier que Prometheus et Grafana collectent et affichent correctement les métriques.
5. **Sécurité** : Vérifier que les groupes de sécurité et les rôles IAM fonctionnent correctement.

## Rollback en cas de problème

En cas de problème avec Amazon Linux 2023, il est possible de revenir à Amazon Linux 2 en modifiant les fichiers suivants :

1. **Modules Terraform** : Modifier les filtres de recherche d'AMI pour utiliser `amzn2-ami-hvm-*-x86_64-gp2` au lieu de `al2023-ami-2023*-x86_64`.
2. **Scripts** : Remplacer `dnf` par `yum` dans tous les scripts.
3. **Variables** : Mettre à jour les descriptions et les valeurs par défaut des variables pour refléter l'utilisation d'Amazon Linux 2.

Il est recommandé de conserver une copie des fichiers originaux avant la migration pour faciliter le rollback si nécessaire.
