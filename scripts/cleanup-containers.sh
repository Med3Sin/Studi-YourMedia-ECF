#!/bin/bash
# Script pour arrêter et supprimer les conteneurs Docker sur les instances EC2

# Variables
EC2_MONITORING_IP=$1
EC2_APP_IP=$2
SSH_KEY_PATH=$3
CLEANUP_TYPE=${4:-"all"} # Type de nettoyage: all, containers, images, volumes, prune

# Afficher la bannière
echo "========================================================="
echo "=== Script de nettoyage des conteneurs Docker YourMedia ==="
echo "========================================================="

# Fonction pour nettoyer les conteneurs sur une instance EC2
cleanup_containers() {
    local ip=$1
    local instance_type=$2
    local cleanup_type=$3

    echo "\n[INFO] Nettoyage des conteneurs Docker sur l'instance $instance_type ($ip)..."
    echo "[INFO] Type de nettoyage: $cleanup_type"

    # Se connecter à l'instance EC2 et arrêter/supprimer les conteneurs
    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        # Sauvegarder les logs avant le nettoyage
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "containers" ]; then
            echo "[INFO] Sauvegarde des logs des conteneurs..."
            mkdir -p ~/docker-logs-backup
            for container in \$(sudo docker ps -a --format "{{.Names}}"); do
                sudo docker logs \$container > ~/docker-logs-backup/\$container-\$(date +%Y%m%d%H%M%S).log 2>&1 || echo "[WARN] Impossible de sauvegarder les logs pour \$container"
            done
            echo "[INFO] Logs sauvegardés dans ~/docker-logs-backup"
        fi

        # Arrêter tous les conteneurs en cours d'exécution
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "containers" ]; then
            echo "[INFO] Arrêt des conteneurs Docker..."
            running_containers=\$(sudo docker ps -q)
            if [ -n "\$running_containers" ]; then
                sudo docker stop \$running_containers
                echo "[INFO] Conteneurs arrêtés: \$(echo \$running_containers | wc -w)"
            else
                echo "[INFO] Aucun conteneur en cours d'exécution"
            fi

            # Supprimer tous les conteneurs
            echo "[INFO] Suppression des conteneurs Docker..."
            all_containers=\$(sudo docker ps -aq)
            if [ -n "\$all_containers" ]; then
                sudo docker rm \$all_containers
                echo "[INFO] Conteneurs supprimés: \$(echo \$all_containers | wc -w)"
            else
                echo "[INFO] Aucun conteneur à supprimer"
            fi
        fi

        # Supprimer les images non utilisées
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "images" ]; then
            echo "[INFO] Suppression des images Docker non utilisées..."
            dangling_images=\$(sudo docker images -f "dangling=true" -q)
            if [ -n "\$dangling_images" ]; then
                sudo docker rmi \$dangling_images
                echo "[INFO] Images dangling supprimées: \$(echo \$dangling_images | wc -w)"
            else
                echo "[INFO] Aucune image dangling à supprimer"
            fi

            # Supprimer toutes les images si demandé
            if [ "$cleanup_type" = "all" ]; then
                echo "[INFO] Suppression de toutes les images Docker..."
                all_images=\$(sudo docker images -q)
                if [ -n "\$all_images" ]; then
                    sudo docker rmi -f \$all_images
                    echo "[INFO] Images supprimées: \$(echo \$all_images | wc -w)"
                else
                    echo "[INFO] Aucune image à supprimer"
                fi
            fi
        fi

        # Supprimer les volumes non utilisés
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "volumes" ]; then
            echo "[INFO] Suppression des volumes Docker non utilisés..."
            volumes=\$(sudo docker volume ls -q)
            if [ -n "\$volumes" ]; then
                sudo docker volume rm \$volumes
                echo "[INFO] Volumes supprimés: \$(echo \$volumes | wc -w)"
            else
                echo "[INFO] Aucun volume à supprimer"
            fi
        fi

        # Supprimer tous les réseaux personnalisés
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "networks" ]; then
            echo "[INFO] Suppression des réseaux Docker personnalisés..."
            networks=\$(sudo docker network ls -q -f "type=custom")
            if [ -n "\$networks" ]; then
                sudo docker network rm \$networks
                echo "[INFO] Réseaux supprimés: \$(echo \$networks | wc -w)"
            else
                echo "[INFO] Aucun réseau à supprimer"
            fi
        fi

        # Nettoyage système Docker (prune)
        if [ "$cleanup_type" = "all" ] || [ "$cleanup_type" = "prune" ]; then
            echo "[INFO] Nettoyage système Docker (prune)..."
            sudo docker system prune -af --volumes
            echo "[INFO] Nettoyage système terminé"
        fi

        # Supprimer les fichiers de configuration Docker
        if [ "$cleanup_type" = "all" ]; then
            echo "[INFO] Suppression des fichiers de configuration Docker..."
            sudo rm -rf /opt/monitoring /opt/app-mobile 2>/dev/null || echo "[INFO] Aucun fichier de configuration à supprimer"
        fi

        # Afficher l'espace disque récupéré
        echo "\n[INFO] Espace disque disponible après nettoyage:"
        df -h /

        echo "\n[INFO] Nettoyage terminé sur l'instance $instance_type."
EOF
}

# Fonction d'aide
show_help() {
    echo "\nUsage: $0 <EC2_MONITORING_IP> <EC2_APP_IP> <SSH_KEY_PATH> [CLEANUP_TYPE]\n"
    echo "CLEANUP_TYPE options:"
    echo "  all       - Nettoie tout (conteneurs, images, volumes, réseaux, fichiers) - par défaut"
    echo "  containers - Arrête et supprime uniquement les conteneurs"
    echo "  images     - Supprime uniquement les images Docker"
    echo "  volumes    - Supprime uniquement les volumes Docker"
    echo "  networks   - Supprime uniquement les réseaux Docker personnalisés"
    echo "  prune      - Exécute docker system prune -af --volumes"
    echo "\nExemples:"
    echo "  $0 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa all"
    echo "  $0 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa containers"
    echo "\n"
    exit 1
}

# Vérifier si les adresses IP sont fournies
if [ -z "$EC2_MONITORING_IP" ] || [ -z "$EC2_APP_IP" ] || [ -z "$SSH_KEY_PATH" ]; then
    show_help
fi

# Vérifier si le type de nettoyage est valide
if [ -n "$CLEANUP_TYPE" ] && ! [[ "$CLEANUP_TYPE" =~ ^(all|containers|images|volumes|networks|prune)$ ]]; then
    echo "[ERROR] Type de nettoyage invalide: $CLEANUP_TYPE"
    show_help
fi

# Afficher les informations sur le nettoyage
echo "\n[INFO] Nettoyage des conteneurs Docker sur les instances suivantes:"
echo "  - Instance de monitoring: $EC2_MONITORING_IP"
echo "  - Instance d'application: $EC2_APP_IP"
echo "  - Type de nettoyage: $CLEANUP_TYPE"
echo "\n[INFO] Les logs seront sauvegardés avant le nettoyage."

# Nettoyer les conteneurs sur l'instance de monitoring
cleanup_containers $EC2_MONITORING_IP "monitoring" $CLEANUP_TYPE

# Nettoyer les conteneurs sur l'instance d'application
cleanup_containers $EC2_APP_IP "application" $CLEANUP_TYPE

echo "\n[SUCCESS] Nettoyage des conteneurs Docker terminé sur toutes les instances."
