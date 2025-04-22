#!/bin/bash

# Script simplifié d'installation de Docker pour Amazon Linux 2/2023
# Peut être exécuté avec sudo ou en tant que root

# Fonction pour la journalisation
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Démarrage de l'installation de Docker"

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
  log "Ce script doit être exécuté avec sudo ou en tant que root"
  exit 1
fi

# Déterminer la version d'Amazon Linux
if grep -q "Amazon Linux 2" /etc/os-release; then
  log "Système détecté: Amazon Linux 2"
  # Installation pour Amazon Linux 2
  amazon-linux-extras install docker -y
  systemctl start docker
  systemctl enable docker
elif grep -q "Amazon Linux 2023" /etc/os-release; then
  log "Système détecté: Amazon Linux 2023"
  # Installation pour Amazon Linux 2023
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
  systemctl start docker
  systemctl enable docker
else
  log "Système non reconnu: $(cat /etc/os-release | grep PRETTY_NAME)"
  log "Tentative d'installation avec la méthode standard..."
  yum install -y docker
  systemctl start docker
  systemctl enable docker
fi

# Ajouter l'utilisateur ec2-user au groupe docker
usermod -aG docker ec2-user
log "Utilisateur ec2-user ajouté au groupe docker"

# Installer Docker Compose
log "Installation de Docker Compose"
COMPOSE_VERSION="v2.20.3"
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Vérifier l'installation
if docker --version; then
  log "Docker installé avec succès: $(docker --version)"
else
  log "ATTENTION: Impossible de vérifier la version de Docker"
fi

if docker-compose --version; then
  log "Docker Compose installé avec succès: $(docker-compose --version)"
else
  log "ATTENTION: Impossible de vérifier la version de Docker Compose"
fi

# Tester Docker avec hello-world
log "Test de Docker avec hello-world"
docker run --rm hello-world || log "ATTENTION: Le test hello-world a échoué"

log "Installation terminée"
echo ""
echo "Docker a été installé avec succès!"
echo "Pour utiliser Docker sans sudo, déconnectez-vous et reconnectez-vous,"
echo "ou exécutez la commande suivante: newgrp docker"
echo ""
