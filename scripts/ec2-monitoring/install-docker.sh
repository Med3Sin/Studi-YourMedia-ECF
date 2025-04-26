#!/bin/bash

# Script d'installation de Docker pour Amazon Linux 2023
# Ce script utilise le script d'installation officiel de Docker
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./install-docker.sh

# Fonction pour la journalisation
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
  log "ERREUR: $1"
  exit 1
}

log "Démarrage de l'installation de Docker"

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
  error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Afficher les informations du système
log "Informations du système:"
cat /etc/os-release

# Installation pour Amazon Linux 2023
log "Système détecté: Amazon Linux 2023"

log "Mise à jour des paquets"
dnf update -y || error_exit "Impossible de mettre à jour les paquets"

log "Installation de Docker natif pour Amazon Linux 2023"
dnf install -y docker || error_exit "Impossible d'installer Docker"

log "Démarrage du service Docker"
systemctl start docker || error_exit "Impossible de démarrer le service Docker"

log "Activation du service Docker au démarrage"
systemctl enable docker || error_exit "Impossible d'activer le service Docker au démarrage"

log "Vérification du statut du service Docker"
systemctl status docker

# Créer le groupe docker s'il n'existe pas
getent group docker &>/dev/null || groupadd docker

# Ajouter l'utilisateur ec2-user au groupe docker
usermod -aG docker ec2-user || log "ATTENTION: Impossible d'ajouter l'utilisateur ec2-user au groupe docker"
log "Utilisateur ec2-user ajouté au groupe docker"

# Installer Docker Compose
log "Installation de Docker Compose"
COMPOSE_VERSION="v2.20.3"
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Impossible de télécharger Docker Compose"
chmod +x /usr/local/bin/docker-compose || error_exit "Impossible de rendre Docker Compose exécutable"
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Vérifier l'installation
log "Vérification de l'installation de Docker"
if docker --version; then
  log "Docker installé avec succès: $(docker --version)"
else
  log "ATTENTION: Impossible de vérifier la version de Docker"
fi

log "Vérification de l'installation de Docker Compose"
if docker-compose --version; then
  log "Docker Compose installé avec succès: $(docker-compose --version)"
else
  log "ATTENTION: Impossible de vérifier la version de Docker Compose"
fi

# Tester Docker avec hello-world
log "Test de Docker avec hello-world"
docker run --rm hello-world || log "ATTENTION: Le test hello-world a échoué"

log "Installation terminée avec succès"
echo ""
echo "Docker a été installé avec succès!"
echo "Pour utiliser Docker sans sudo, déconnectez-vous et reconnectez-vous,"
echo "ou exécutez la commande suivante: newgrp docker"
echo ""

# Vérifier que Docker fonctionne correctement
docker ps
