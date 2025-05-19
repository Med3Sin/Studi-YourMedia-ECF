#!/bin/bash
#==============================================================================
# Nom du script : start-containers.sh
# Description   : Script pour démarrer les conteneurs Docker
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
#==============================================================================
# Utilisation   : sudo ./start-containers.sh
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root ou avec sudo"
fi

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    log_info "Docker n'est pas installé, installation en cours..."
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user
    log_success "Docker installé avec succès"
else
    log_info "Docker est déjà installé"
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    log_info "Docker Compose n'est pas installé, installation en cours..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    log_success "Docker Compose installé avec succès"
else
    log_info "Docker Compose est déjà installé"
fi

# Se connecter à Docker Hub
log_info "Connexion à Docker Hub"
if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
    if [ $? -ne 0 ]; then
        log_error "Échec de la connexion à Docker Hub"
    fi
    log_success "Connexion à Docker Hub réussie"
else
    log_info "Variables DOCKERHUB_USERNAME et/ou DOCKERHUB_TOKEN non définies, connexion à Docker Hub ignorée"
fi

# Vérifier si le répertoire de configuration existe
if [ ! -d "/opt/monitoring" ]; then
    log_info "Création du répertoire /opt/monitoring"
    mkdir -p /opt/monitoring
fi

# Vérifier si le fichier docker-compose.yml existe
if [ ! -f "/opt/monitoring/docker-compose.yml" ]; then
    log_info "Le fichier docker-compose.yml n'existe pas, exécution du script setup-config-files.sh"
    if [ -f "/home/ec2-user/scripts/ec2-monitoring/setup-config-files.sh" ]; then
        /home/ec2-user/scripts/ec2-monitoring/setup-config-files.sh
    else
        log_error "Le script setup-config-files.sh n'existe pas"
    fi
fi

# Démarrer les conteneurs
log_info "Démarrage des conteneurs"
cd /opt/monitoring
docker-compose down
docker-compose up -d

# Vérifier si les conteneurs sont démarrés
log_info "Vérification des conteneurs"
if [ "$(docker ps -q | wc -l)" -eq 0 ]; then
    log_error "Aucun conteneur n'est démarré"
fi

# Afficher les conteneurs en cours d'exécution
log_info "Conteneurs en cours d'exécution :"
docker ps

log_success "Démarrage des conteneurs terminé avec succès"
exit 0
