#!/bin/bash

# Script amélioré de déploiement des conteneurs Docker pour le monitoring
# Ce script inclut des vérifications supplémentaires et des messages d'erreur plus détaillés

# Fonction pour afficher les messages d'erreur
error_exit() {
    echo "ERREUR: $1" >&2
    exit 1
}

# Vérifier si l'utilisateur a les permissions sudo
if ! sudo -n true 2>/dev/null; then
    error_exit "Ce script nécessite des privilèges sudo. Exécutez-le avec 'sudo' ou en tant qu'utilisateur avec des privilèges sudo."
fi

echo "=== Début du déploiement des conteneurs de monitoring ==="

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Installation en cours..."
    sudo yum update -y || error_exit "Impossible de mettre à jour les packages"
    sudo amazon-linux-extras install docker -y || error_exit "Impossible d'installer Docker"
    sudo systemctl start docker || error_exit "Impossible de démarrer Docker"
    sudo systemctl enable docker || error_exit "Impossible d'activer Docker au démarrage"
    sudo usermod -a -G docker ec2-user || error_exit "Impossible d'ajouter l'utilisateur au groupe docker"
    echo "Docker a été installé avec succès."
else
    echo "Docker est déjà installé."
fi

# Vérifier si Docker est en cours d'exécution
if ! sudo systemctl is-active --quiet docker; then
    echo "Docker n'est pas en cours d'exécution. Démarrage de Docker..."
    sudo systemctl start docker || error_exit "Impossible de démarrer Docker"
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose n'est pas installé. Installation en cours..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Impossible de télécharger Docker Compose"
    sudo chmod +x /usr/local/bin/docker-compose || error_exit "Impossible de rendre Docker Compose exécutable"
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    echo "Docker Compose a été installé avec succès."
else
    echo "Docker Compose est déjà installé."
fi

# Création des répertoires pour les volumes
echo "Création des répertoires pour les volumes..."
sudo mkdir -p /opt/monitoring/prometheus-data || error_exit "Impossible de créer le répertoire prometheus-data"
sudo mkdir -p /opt/monitoring/grafana-data || error_exit "Impossible de créer le répertoire grafana-data"
sudo chown -R ec2-user:ec2-user /opt/monitoring || error_exit "Impossible de changer le propriétaire des répertoires"

# Vérifier si les fichiers de configuration existent dans /tmp
if [ -f /tmp/docker-compose.yml ] && [ -f /tmp/prometheus.yml ]; then
    echo "Copie des fichiers de configuration depuis /tmp..."
    cp /tmp/docker-compose.yml /opt/monitoring/ || error_exit "Impossible de copier docker-compose.yml"
    cp /tmp/prometheus.yml /opt/monitoring/ || error_exit "Impossible de copier prometheus.yml"
else
    echo "Les fichiers de configuration n'existent pas dans /tmp."
    
    # Vérifier si les fichiers existent déjà dans /opt/monitoring
    if [ ! -f /opt/monitoring/docker-compose.yml ] || [ ! -f /opt/monitoring/prometheus.yml ]; then
        error_exit "Les fichiers de configuration n'existent pas. Veuillez les créer manuellement."
    else
        echo "Les fichiers de configuration existent déjà dans /opt/monitoring."
    fi
fi

# Arrêter les conteneurs existants s'ils sont en cours d'exécution
echo "Arrêt des conteneurs existants s'ils sont en cours d'exécution..."
cd /opt/monitoring
docker-compose down 2>/dev/null || true

# Démarrage des conteneurs
echo "Démarrage des conteneurs..."
cd /opt/monitoring
docker-compose up -d || error_exit "Impossible de démarrer les conteneurs"

# Attendre que les conteneurs démarrent
echo "Attente du démarrage des conteneurs..."
sleep 5

# Vérification du statut des conteneurs
echo "Statut des conteneurs:"
docker ps || error_exit "Impossible d'afficher le statut des conteneurs"

# Vérifier si les conteneurs sont en cours d'exécution
if docker ps | grep -q "prometheus" && docker ps | grep -q "grafana"; then
    echo "Les conteneurs Prometheus et Grafana sont en cours d'exécution."
    
    # Récupérer l'adresse IP publique
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    echo ""
    echo "=== Déploiement terminé avec succès! ==="
    echo ""
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
    error_exit "Les conteneurs ne sont pas en cours d'exécution. Vérifiez les logs pour plus d'informations."
fi
