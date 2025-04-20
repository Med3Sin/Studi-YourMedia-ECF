#!/bin/bash
# Script pour arrêter et supprimer les conteneurs Docker sur les instances EC2

# Variables
EC2_MONITORING_IP=$1
EC2_APP_IP=$2
SSH_KEY_PATH=$3

# Fonction pour nettoyer les conteneurs sur une instance EC2
cleanup_containers() {
    local ip=$1
    local instance_type=$2
    
    echo "Nettoyage des conteneurs Docker sur l'instance $instance_type ($ip)..."
    
    # Se connecter à l'instance EC2 et arrêter/supprimer les conteneurs
    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        # Arrêter tous les conteneurs en cours d'exécution
        echo "Arrêt des conteneurs Docker..."
        sudo docker stop \$(sudo docker ps -aq) 2>/dev/null || echo "Aucun conteneur à arrêter"
        
        # Supprimer tous les conteneurs
        echo "Suppression des conteneurs Docker..."
        sudo docker rm \$(sudo docker ps -aq) 2>/dev/null || echo "Aucun conteneur à supprimer"
        
        # Supprimer toutes les images
        echo "Suppression des images Docker..."
        sudo docker rmi \$(sudo docker images -q) 2>/dev/null || echo "Aucune image à supprimer"
        
        # Supprimer tous les volumes
        echo "Suppression des volumes Docker..."
        sudo docker volume rm \$(sudo docker volume ls -q) 2>/dev/null || echo "Aucun volume à supprimer"
        
        # Supprimer tous les réseaux personnalisés
        echo "Suppression des réseaux Docker..."
        sudo docker network rm \$(sudo docker network ls -q -f "type=custom") 2>/dev/null || echo "Aucun réseau à supprimer"
        
        # Supprimer les fichiers de configuration Docker
        echo "Suppression des fichiers de configuration Docker..."
        sudo rm -rf /opt/monitoring /opt/app-mobile 2>/dev/null || echo "Aucun fichier de configuration à supprimer"
        
        echo "Nettoyage terminé sur l'instance $instance_type."
EOF
}

# Vérifier si les adresses IP sont fournies
if [ -z "$EC2_MONITORING_IP" ] || [ -z "$EC2_APP_IP" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "Usage: $0 <EC2_MONITORING_IP> <EC2_APP_IP> <SSH_KEY_PATH>"
    exit 1
fi

# Nettoyer les conteneurs sur l'instance de monitoring
cleanup_containers $EC2_MONITORING_IP "monitoring"

# Nettoyer les conteneurs sur l'instance d'application
cleanup_containers $EC2_APP_IP "application"

echo "Nettoyage des conteneurs Docker terminé sur toutes les instances."
