#!/bin/bash

#############################################################################
# Script d'installation et de déploiement pour Grafana et Prometheus
# 
# Ce script installe Docker et Docker Compose, puis déploie les conteneurs
# Grafana et Prometheus pour le monitoring de l'application.
#
# Fonctionnalités :
# - Installation automatique de Docker et Docker Compose si nécessaire
# - Création des répertoires pour les volumes Docker
# - Déploiement des conteneurs avec docker-compose
# - Vérification du bon fonctionnement des services
#
# Auteur: Med3Sin
# Date: 2025-04-13
#############################################################################

# Afficher un message avec formatage
print_section() {
    echo ""
    echo "===================================================================="
    echo "  $1"
    echo "===================================================================="
    echo ""
}

# Afficher un message d'information
print_info() {
    echo "[INFO] $1"
}

# Afficher un message de succès
print_success() {
    echo "[SUCCÈS] $1"
}

# Afficher un message d'erreur et quitter
error_exit() {
    echo "[ERREUR] $1" >&2
    exit 1
}

# Vérifier si l'utilisateur a les permissions sudo
if ! sudo -n true 2>/dev/null; then
    error_exit "Ce script nécessite des privilèges sudo. Exécutez-le avec 'sudo' ou en tant qu'utilisateur avec des privilèges sudo."
fi

print_section "Déploiement des conteneurs de monitoring"

#############################################################################
# ÉTAPE 1 : Installation de Docker
#############################################################################
print_section "Installation de Docker"

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    print_info "Docker n'est pas installé. Installation en cours..."
    sudo yum update -y || error_exit "Impossible de mettre à jour les packages"
    sudo amazon-linux-extras install docker -y || error_exit "Impossible d'installer Docker"
    sudo systemctl start docker || error_exit "Impossible de démarrer Docker"
    sudo systemctl enable docker || error_exit "Impossible d'activer Docker au démarrage"
    sudo usermod -a -G docker ec2-user || error_exit "Impossible d'ajouter l'utilisateur au groupe docker"
    print_success "Docker a été installé avec succès"
else
    print_info "Docker est déjà installé"
fi

# Vérifier si Docker est en cours d'exécution
if ! sudo systemctl is-active --quiet docker; then
    print_info "Docker n'est pas en cours d'exécution. Démarrage de Docker..."
    sudo systemctl start docker || error_exit "Impossible de démarrer Docker"
    print_success "Docker a été démarré avec succès"
else
    print_info "Docker est déjà en cours d'exécution"
fi

#############################################################################
# ÉTAPE 2 : Installation de Docker Compose
#############################################################################
print_section "Installation de Docker Compose"

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    print_info "Docker Compose n'est pas installé. Installation en cours..."
    # Télécharger la dernière version stable de Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Impossible de télécharger Docker Compose"
    sudo chmod +x /usr/local/bin/docker-compose || error_exit "Impossible de rendre Docker Compose exécutable"
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    print_success "Docker Compose a été installé avec succès"
else
    print_info "Docker Compose est déjà installé"
fi

#############################################################################
# ÉTAPE 3 : Préparation des répertoires et fichiers de configuration
#############################################################################
print_section "Préparation de l'environnement"

# Création des répertoires pour les volumes
print_info "Création des répertoires pour les volumes Docker..."
sudo mkdir -p /opt/monitoring/prometheus-data || error_exit "Impossible de créer le répertoire prometheus-data"
sudo mkdir -p /opt/monitoring/grafana-data || error_exit "Impossible de créer le répertoire grafana-data"
sudo chown -R ec2-user:ec2-user /opt/monitoring || error_exit "Impossible de changer le propriétaire des répertoires"
print_success "Répertoires créés avec succès"

#############################################################################
# ÉTAPE 4 : Déploiement des conteneurs
#############################################################################
print_section "Déploiement des conteneurs"

# Arrêter les conteneurs existants s'ils sont en cours d'exécution
print_info "Arrêt des conteneurs existants s'ils sont en cours d'exécution..."
cd /opt/monitoring
docker-compose down 2>/dev/null || true

# Démarrage des conteneurs
print_info "Démarrage des conteneurs..."
cd /opt/monitoring
docker-compose up -d || error_exit "Impossible de démarrer les conteneurs"
print_success "Conteneurs démarrés avec succès"

# Attendre que les conteneurs démarrent
print_info "Attente du démarrage des conteneurs..."
sleep 5

#############################################################################
# ÉTAPE 5 : Vérification
#############################################################################
print_section "Vérification"

print_info "Statut des conteneurs:"
docker ps || error_exit "Impossible d'afficher le statut des conteneurs"

# Vérifier si les conteneurs sont en cours d'exécution
if docker ps | grep -q "prometheus" && docker ps | grep -q "grafana"; then
    print_success "Les conteneurs Prometheus et Grafana sont en cours d'exécution"
    
    # Récupérer l'adresse IP publique
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    echo ""
    print_section "Accès aux interfaces web"
    echo "Vous pouvez accéder aux interfaces web:"
    echo "- Prometheus: http://$PUBLIC_IP:9090"
    echo "- Grafana: http://$PUBLIC_IP:3000"
    echo ""
    echo "Identifiants Grafana par défaut:"
    echo "- Utilisateur: admin"
    echo "- Mot de passe: admin"
    echo ""
    echo "N'oubliez pas de vérifier que les ports 3000 et 9090 sont ouverts dans votre groupe de sécurité AWS."
else
    error_exit "Les conteneurs ne sont pas en cours d'exécution. Vérifiez les logs pour plus d'informations"
fi
