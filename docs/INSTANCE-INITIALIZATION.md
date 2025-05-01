# Initialisation des Instances EC2

Ce document décrit le processus d'initialisation des instances EC2 dans le projet YourMédia, en particulier les améliorations apportées pour résoudre les problèmes de transmission des variables d'environnement et d'installation des composants nécessaires.

> **Note importante** : L'infrastructure YourMedia utilise deux types d'instances EC2 distinctes :
> - **Instance EC2 Java Tomcat** : Dédiée à l'exécution de l'application Java backend via Tomcat (sans Docker)
> - **Instance EC2 Monitoring** : Dédiée à l'exécution des services de monitoring via Docker
>
> Pour plus de détails sur cette séparation, consultez le document [INSTANCE-ROLES-SEPARATION.md](INSTANCE-ROLES-SEPARATION.md).

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Problèmes identifiés](#problèmes-identifiés)
3. [Solutions implémentées](#solutions-implémentées)
4. [Scripts d'initialisation](#scripts-dinitialisation)
5. [Gestion des variables d'environnement](#gestion-des-variables-denvironnement)
6. [Installation de Docker](#installation-de-docker)
7. [Dépannage](#dépannage)

## Vue d'ensemble

Les instances EC2 du projet YourMédia (Java/Tomcat et Monitoring) sont initialisées à l'aide de scripts qui sont téléchargés directement depuis GitHub. Cette nouvelle approche remplace l'ancienne méthode qui utilisait un bucket S3 pour stocker les scripts. Les scripts configurent l'environnement, installent les dépendances nécessaires et déploient les applications.

> **Note importante** : Depuis la version 2.0 du projet, les scripts sont téléchargés directement depuis GitHub au lieu d'être stockés dans un bucket S3. Pour plus de détails sur cette nouvelle approche, consultez le document [SCRIPTS-GITHUB-APPROACH.md](SCRIPTS-GITHUB-APPROACH.md).

## Problèmes identifiés

Plusieurs problèmes ont été identifiés dans le processus d'initialisation des instances EC2 :

1. **Transmission des variables d'environnement** : Les variables d'environnement n'étaient pas correctement transmises aux scripts d'initialisation, ce qui entraînait des erreurs lors du téléchargement des scripts.

2. **Installation de Docker** : L'installation de Docker échouait parfois, ce qui empêchait le déploiement des conteneurs.

3. **Gestion des erreurs** : Les scripts ne géraient pas correctement les erreurs, ce qui rendait difficile le diagnostic des problèmes.

## Solutions implémentées

Pour résoudre ces problèmes, les modifications suivantes ont été apportées :

### 1. Amélioration de la transmission des variables d'environnement

- Définition explicite des variables d'environnement dans le script `user_data` de Terraform
- Vérification de l'existence des variables d'environnement requises
- Utilisation de `sudo -E` pour préserver les variables d'environnement lors de l'exécution des scripts avec sudo

### 2. Renforcement de l'installation de Docker

- Ajout d'une méthode d'installation manuelle de Docker en cas d'échec du script d'installation
- Vérification de l'installation de Docker après l'exécution du script
- Affichage de la version de Docker pour confirmer l'installation

### 3. Amélioration de la gestion des erreurs

- Ajout de vérifications d'erreur pour chaque étape critique
- Utilisation de la commande `|| error_exit` pour arrêter le script en cas d'erreur
- Affichage des variables d'environnement pour faciliter le débogage

## Scripts d'initialisation

### Script `user_data` dans Terraform

Le script `user_data` dans le fichier Terraform a été modifié pour :

1. Définir explicitement les variables d'environnement
2. Vérifier que le nom du bucket S3 est défini
3. Utiliser `sudo -E` pour préserver les variables d'environnement

```hcl
user_data = <<-EOF
#!/bin/bash

# Mettre à jour le système et installer les dépendances
sudo dnf update -y
sudo dnf install -y amazon-cloudwatch-agent

# Créer le répertoire .ssh s'il n'existe pas
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Installer la clé SSH publique
echo "${var.ssh_public_key}" | sudo tee -a /home/ec2-user/.ssh/authorized_keys
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Définir les variables d'environnement pour le script
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
DB_USERNAME="${var.db_username}"
DB_PASSWORD="${var.db_password}"
RDS_ENDPOINT="${var.rds_endpoint}"
GRAFANA_ADMIN_PASSWORD="${var.grafana_admin_password}"

# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/monitoring
GITHUB_RAW_URL="https://raw.githubusercontent.com/${var.repo_owner}/${var.repo_name}/main"
sudo curl -s -o /opt/monitoring/init-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/init-monitoring.sh"
sudo chmod +x /opt/monitoring/init-monitoring.sh

# Exporter les variables d'environnement pour le script
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export DB_USERNAME="$DB_USERNAME"
export DB_PASSWORD="$DB_PASSWORD"
export RDS_ENDPOINT="$RDS_ENDPOINT"
export GRAFANA_ADMIN_PASSWORD="$GRAFANA_ADMIN_PASSWORD"

# Exécuter le script d'initialisation avec les variables d'environnement
sudo -E /opt/monitoring/init-monitoring.sh
EOF
```

### Script d'initialisation `init-monitoring.sh`

Le script d'initialisation a été modifié pour :

1. Vérifier l'existence des variables d'environnement requises
2. Ajouter des vérifications d'erreur pour chaque étape critique
3. Télécharger les scripts supplémentaires depuis GitHub
4. Installer Docker manuellement si le script d'installation échoue

```bash
#!/bin/bash
# Script d'initialisation pour l'instance EC2 de monitoring

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

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

# Création des répertoires nécessaires
log "Création des répertoires nécessaires"
sudo mkdir -p /opt/monitoring
sudo mkdir -p /opt/monitoring/config
sudo mkdir -p /opt/monitoring/data
sudo mkdir -p /opt/monitoring/logs
sudo mkdir -p /opt/monitoring/secure

# Configuration des clés SSH
log "Configuration des clés SSH"
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Récupération de la clé publique depuis les métadonnées
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
fi
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency curl curl
check_dependency jq jq

# Afficher les variables d'environnement pour le débogage
log "Variables d'environnement:"
log "EC2_INSTANCE_PRIVATE_IP=$EC2_INSTANCE_PRIVATE_IP"

# Téléchargement des scripts depuis GitHub
log "Téléchargement des scripts depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Téléchargement du script de configuration
log "Téléchargement du script setup-monitoring.sh"
curl -s -o /opt/monitoring/setup-monitoring.sh "$GITHUB_RAW_URL/scripts/ec2-monitoring/setup-monitoring.sh"
chmod +x /opt/monitoring/setup-monitoring.sh

# Téléchargement des fichiers de configuration supplémentaires depuis GitHub
log "Téléchargement des fichiers de configuration supplémentaires depuis GitHub"

# Téléchargement des fichiers de configuration Prometheus
log "Téléchargement des fichiers de configuration Prometheus"
mkdir -p /opt/monitoring/config/prometheus
curl -s -o /opt/monitoring/config/prometheus/prometheus.yml "$GITHUB_RAW_URL/scripts/config/prometheus/prometheus.yml"
curl -s -o /opt/monitoring/config/prometheus/container-alerts.yml "$GITHUB_RAW_URL/scripts/config/prometheus/container-alerts.yml"

# Téléchargement des fichiers de configuration Grafana
log "Téléchargement des fichiers de configuration Grafana"
mkdir -p /opt/monitoring/config/grafana
curl -s -o /opt/monitoring/config/grafana/grafana.ini "$GITHUB_RAW_URL/scripts/config/grafana/grafana.ini"

# Téléchargement des fichiers de configuration Loki et Promtail
log "Téléchargement des fichiers de configuration Loki et Promtail"
curl -s -o /opt/monitoring/config/loki-config.yml "$GITHUB_RAW_URL/scripts/config/loki-config.yml"
curl -s -o /opt/monitoring/config/promtail-config.yml "$GITHUB_RAW_URL/scripts/config/promtail-config.yml"

# Téléchargement du fichier docker-compose.yml
log "Téléchargement du fichier docker-compose.yml"
curl -s -o /opt/monitoring/docker-compose.yml "$GITHUB_RAW_URL/scripts/ec2-monitoring/docker-compose.yml"

# Création d'un fichier de variables d'environnement pour les scripts
log "Création du fichier de variables d'environnement"
cat > /tmp/monitoring-env.sh << EOF
export EC2_INSTANCE_PRIVATE_IP="${EC2_INSTANCE_PRIVATE_IP}"
export DB_USERNAME="${DB_USERNAME}"
export DB_PASSWORD="${DB_PASSWORD}"
export RDS_ENDPOINT="${RDS_ENDPOINT}"
export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}"
EOF

sudo mv /tmp/monitoring-env.sh /opt/monitoring/env.sh
sudo chmod +x /opt/monitoring/env.sh

# Installation manuelle de Docker si le script échoue
log "Installation de Docker"
if ! command -v docker &> /dev/null; then
    log "Docker n'est pas installé. Installation..."
    sudo dnf update -y
    sudo dnf install -y dnf-utils
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Vérification de l'installation de Docker
if command -v docker &> /dev/null; then
    log "Docker est installé avec succès."
    sudo docker --version
else
    error_exit "L'installation de Docker a échoué."
fi

# Installation de Docker Compose
log "Installation de Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    log "Docker Compose n'est pas installé. Installation..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Vérification de l'installation de Docker Compose
if command -v docker-compose &> /dev/null; then
    log "Docker Compose est installé avec succès."
    docker-compose --version
else
    error_exit "L'installation de Docker Compose a échoué."
fi

# Exécution du script d'installation
log "Exécution du script d'installation"
source /opt/monitoring/env.sh
sudo -E /opt/monitoring/setup-monitoring.sh || error_exit "L'exécution du script setup-monitoring.sh a échoué."

log "Initialisation terminée avec succès"
```

## Gestion des variables d'environnement

Les variables d'environnement sont gérées de la manière suivante :

1. **Définition dans le script `user_data`** : Les variables sont définies dans le script `user_data` de Terraform, en utilisant les valeurs des variables Terraform.

2. **Exportation pour le script d'initialisation** : Les variables sont exportées avant l'exécution du script d'initialisation.

3. **Préservation avec `sudo -E`** : La commande `sudo -E` est utilisée pour préserver les variables d'environnement lors de l'exécution du script avec sudo.

4. **Stockage dans un fichier** : Les variables sont stockées dans un fichier `/opt/monitoring/env.sh` qui est sourcé par les autres scripts.

## Installation de Docker

L'installation de Docker est renforcée de la manière suivante :

1. **Vérification de l'installation** : Le script vérifie si Docker est déjà installé.

2. **Installation via le script** : Si Docker n'est pas installé, le script tente de l'installer via le script `install-docker.sh`.

3. **Installation manuelle** : Si l'installation via le script échoue, le script tente une installation manuelle en utilisant les commandes dnf.

4. **Vérification finale** : Le script vérifie si Docker est correctement installé et affiche sa version.

### Installation de Docker sur Amazon Linux 2023

Le script `install-docker.sh` a été amélioré pour prendre en charge Amazon Linux 2023. Voici les étapes d'installation de Docker sur Amazon Linux 2023 :

```bash
# Mise à jour des paquets
dnf update -y

# Installation de dnf-utils
dnf install -y dnf-utils

# Ajout du dépôt Docker
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Installation de Docker
dnf install -y docker-ce docker-ce-cli containerd.io

# Démarrage du service Docker
systemctl start docker

# Activation du service Docker au démarrage
systemctl enable docker

# Créer le groupe docker s'il n'existe pas
getent group docker &>/dev/null || groupadd docker

# Ajouter l'utilisateur ec2-user au groupe docker
usermod -aG docker ec2-user
```

Pour installer Docker sur Amazon Linux 2023, utilisez le script `scripts/ec2-monitoring/install-docker.sh` qui utilise la méthode d'installation native recommandée :

## Dépannage

Si vous rencontrez des problèmes avec l'initialisation des instances EC2, voici quelques étapes de dépannage :

1. **Vérifier les logs d'initialisation** : Les logs d'initialisation sont disponibles dans le fichier `/var/log/cloud-init-output.log` sur l'instance EC2.

2. **Vérifier les variables d'environnement** : Les variables d'environnement sont affichées dans les logs d'initialisation. Vérifiez que la variable `S3_BUCKET_NAME` est correctement définie.

3. **Vérifier l'installation de Docker** : Vous pouvez vérifier l'installation de Docker en exécutant la commande `docker --version` sur l'instance EC2.

4. **Réexécuter le script d'initialisation** : Si nécessaire, vous pouvez réexécuter le script d'initialisation en exécutant la commande `sudo /opt/monitoring/init-instance-env.sh` sur l'instance EC2.

5. **Installer Docker manuellement** : Si l'installation de Docker échoue, vous pouvez l'installer manuellement en exécutant les commandes suivantes sur l'instance EC2 :

```bash
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
```
