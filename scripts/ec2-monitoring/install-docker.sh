#!/bin/bash

# Script amélioré d'installation de Docker pour Amazon Linux 2023
# Peut être exécuté avec sudo ou en tant que root

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

# Déterminer la version d'Amazon Linux
if grep -q "Amazon Linux 2023" /etc/os-release; then
  log "Système détecté: Amazon Linux 2023"

  # Installation pour Amazon Linux 2023
  log "Mise à jour des paquets"
  dnf update -y || error_exit "Impossible de mettre à jour les paquets"

  log "Installation de dnf-utils"
  dnf install -y dnf-utils || error_exit "Impossible d'installer dnf-utils"

  log "Ajout du dépôt Docker"
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || error_exit "Impossible d'ajouter le dépôt Docker"

  log "Installation de Docker"
  dnf install -y docker-ce docker-ce-cli containerd.io || error_exit "Impossible d'installer Docker"

  log "Démarrage du service Docker"
  systemctl start docker || error_exit "Impossible de démarrer le service Docker"

  log "Activation du service Docker au démarrage"
  systemctl enable docker || error_exit "Impossible d'activer le service Docker au démarrage"

  log "Vérification du statut du service Docker"
  systemctl status docker
elif grep -q "Amazon Linux 2" /etc/os-release; then
  log "Système détecté: Amazon Linux 2"

  # Installation pour Amazon Linux 2
  log "Installation de Docker via amazon-linux-extras"
  amazon-linux-extras install docker -y || error_exit "Impossible d'installer Docker via amazon-linux-extras"

  log "Démarrage du service Docker"
  systemctl start docker || error_exit "Impossible de démarrer le service Docker"

  log "Activation du service Docker au démarrage"
  systemctl enable docker || error_exit "Impossible d'activer le service Docker au démarrage"

  log "Vérification du statut du service Docker"
  systemctl status docker
else
  log "Système non reconnu: $(cat /etc/os-release | grep PRETTY_NAME)"
  log "Tentative d'installation avec la méthode standard..."

  # Tentative d'installation générique
  if command -v dnf &> /dev/null; then
    log "Utilisation de dnf pour l'installation"
    dnf update -y
    dnf install -y dnf-utils
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io
  elif command -v yum &> /dev/null; then
    log "Utilisation de yum pour l'installation"
    yum update -y
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
  else
    error_exit "Aucun gestionnaire de paquets reconnu (dnf/yum) n'a été trouvé"
  fi

  log "Démarrage du service Docker"
  systemctl start docker || error_exit "Impossible de démarrer le service Docker"

  log "Activation du service Docker au démarrage"
  systemctl enable docker || error_exit "Impossible d'activer le service Docker au démarrage"
fi

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
