#!/bin/bash

# Script d'installation de Docker pour Amazon Linux 2/2023
# Ce script doit être exécuté avec les privilèges root

# Fonction pour la journalisation
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/docker-install.log
}

# Démarrer la journalisation
log "Démarrage de l'installation de Docker"

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  log "ERREUR: Ce script doit être exécuté en tant que root"
  exit 1
fi

# Déterminer la version d'Amazon Linux
if grep -q "Amazon Linux 2" /etc/os-release; then
  AMAZON_LINUX_VERSION="2"
  log "Système détecté: Amazon Linux 2"
elif grep -q "Amazon Linux 2023" /etc/os-release; then
  AMAZON_LINUX_VERSION="2023"
  log "Système détecté: Amazon Linux 2023"
else
  log "ERREUR: Ce script est conçu pour Amazon Linux 2 ou Amazon Linux 2023"
  log "Système détecté: $(cat /etc/os-release)"
  exit 1
fi

# Mettre à jour le système
log "Mise à jour du système"
yum update -y || {
  log "ERREUR: Impossible de mettre à jour le système"
  exit 1
}

# Installer les dépendances
log "Installation des dépendances"
yum install -y yum-utils device-mapper-persistent-data lvm2 || {
  log "ERREUR: Impossible d'installer les dépendances"
  exit 1
}

# Installation de Docker selon la version d'Amazon Linux
if [ "$AMAZON_LINUX_VERSION" = "2" ]; then
  # Amazon Linux 2
  log "Installation de Docker via amazon-linux-extras"
  yum install -y amazon-linux-extras || {
    log "ERREUR: Impossible d'installer amazon-linux-extras"
    exit 1
  }
  
  amazon-linux-extras enable docker || {
    log "ERREUR: Impossible d'activer le dépôt Docker"
    exit 1
  }
  
  yum install -y docker || {
    log "ERREUR: Impossible d'installer Docker"
    exit 1
  }
else
  # Amazon Linux 2023
  log "Installation de Docker via le dépôt Docker CE"
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || {
    log "ERREUR: Impossible d'ajouter le dépôt Docker CE"
    exit 1
  }
  
  yum install -y docker-ce docker-ce-cli containerd.io || {
    log "ERREUR: Impossible d'installer Docker CE"
    exit 1
  }
fi

# Démarrer et activer Docker
log "Démarrage et activation de Docker"
systemctl start docker || {
  log "ERREUR: Impossible de démarrer Docker"
  exit 1
}

systemctl enable docker || {
  log "ERREUR: Impossible d'activer Docker au démarrage"
  exit 1
}

# Ajouter l'utilisateur ec2-user au groupe docker
log "Ajout de l'utilisateur ec2-user au groupe docker"
usermod -aG docker ec2-user || {
  log "ERREUR: Impossible d'ajouter l'utilisateur ec2-user au groupe docker"
  exit 1
}

# Installer Docker Compose
log "Installation de Docker Compose"
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

if [ -z "$COMPOSE_VERSION" ]; then
  log "AVERTISSEMENT: Impossible de déterminer la dernière version de Docker Compose, utilisation de la version 2.20.3"
  COMPOSE_VERSION="v2.20.3"
fi

log "Installation de Docker Compose version $COMPOSE_VERSION"
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || {
  log "ERREUR: Impossible de télécharger Docker Compose"
  exit 1
}

chmod +x /usr/local/bin/docker-compose || {
  log "ERREUR: Impossible de rendre Docker Compose exécutable"
  exit 1
}

ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || {
  log "AVERTISSEMENT: Impossible de créer le lien symbolique pour Docker Compose"
}

# Vérifier l'installation
log "Vérification de l'installation de Docker"
docker --version || {
  log "ERREUR: Docker n'est pas correctement installé"
  exit 1
}

log "Vérification de l'installation de Docker Compose"
docker-compose --version || {
  log "ERREUR: Docker Compose n'est pas correctement installé"
  exit 1
}

# Configurer le stockage Docker
log "Configuration du stockage Docker"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Redémarrer Docker pour appliquer les changements
log "Redémarrage de Docker pour appliquer les changements"
systemctl restart docker || {
  log "ERREUR: Impossible de redémarrer Docker"
  exit 1
}

# Vérifier que Docker fonctionne correctement
log "Vérification du fonctionnement de Docker"
docker run --rm hello-world || {
  log "ERREUR: Docker ne fonctionne pas correctement"
  exit 1
}

log "Installation de Docker terminée avec succès"
log "Docker version: $(docker --version)"
log "Docker Compose version: $(docker-compose --version)"

# Instructions pour l'utilisateur
echo ""
echo "Docker a été installé avec succès!"
echo "Pour utiliser Docker sans sudo, déconnectez-vous et reconnectez-vous,"
echo "ou exécutez la commande suivante: newgrp docker"
echo ""
