#!/bin/bash
# Script pour sauvegarder et restaurer les données des conteneurs Docker sur les instances EC2

# Variables
EC2_MONITORING_IP=$1
EC2_APP_IP=$2
SSH_KEY_PATH=$3
ACTION=$4 # backup ou restore
S3_BUCKET=$5 # Bucket S3 pour stocker les sauvegardes

# Afficher la bannière
echo "========================================================="
echo "=== Script de sauvegarde/restauration des conteneurs YourMedia ==="
echo "========================================================="

# Fonction d'aide
show_help() {
    echo -e "\nUsage: $0 <EC2_MONITORING_IP> <EC2_APP_IP> <SSH_KEY_PATH> <ACTION> [S3_BUCKET]\n"
    echo "ACTION options:"
    echo "  backup   - Sauvegarde les données des conteneurs"
    echo "  restore  - Restaure les données des conteneurs à partir d'une sauvegarde"
    echo -e "\nExemples:"
    echo "  $0 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa backup yourmedia-backups"
    echo "  $0 192.168.1.10 192.168.1.11 ~/.ssh/id_rsa restore yourmedia-backups"
    echo -e "\n"
    exit 1
}

# Vérifier si les paramètres sont fournis
if [ -z "$EC2_MONITORING_IP" ] || [ -z "$EC2_APP_IP" ] || [ -z "$SSH_KEY_PATH" ] || [ -z "$ACTION" ]; then
    show_help
fi

# Vérifier si l'action est valide
if [ "$ACTION" != "backup" ] && [ "$ACTION" != "restore" ]; then
    echo "[ERROR] Action invalide: $ACTION. Utilisez 'backup' ou 'restore'."
    show_help
fi

# Vérifier si le bucket S3 est fourni pour la sauvegarde
if [ "$ACTION" = "backup" ] && [ -z "$S3_BUCKET" ]; then
    echo "[ERROR] Le bucket S3 est requis pour la sauvegarde."
    show_help
fi

# Vérifier si le bucket S3 est fourni pour la restauration
if [ "$ACTION" = "restore" ] && [ -z "$S3_BUCKET" ]; then
    echo "[ERROR] Le bucket S3 est requis pour la restauration."
    show_help
fi

# Fonction pour sauvegarder les données des conteneurs
backup_containers() {
    local ip=$1
    local instance_type=$2
    local s3_bucket=$3
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_dir="yourmedia-backup-${instance_type}-${timestamp}"
    
    echo -e "\n[INFO] Sauvegarde des données des conteneurs sur l'instance $instance_type ($ip)..."
    
    # Se connecter à l'instance EC2 et sauvegarder les données
    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        echo "[INFO] Création du répertoire de sauvegarde..."
        mkdir -p ~/$backup_dir

        # Sauvegarder les configurations Docker
        echo "[INFO] Sauvegarde des configurations Docker..."
        if [ -d "/opt/monitoring" ]; then
            tar -czf ~/$backup_dir/monitoring-config.tar.gz /opt/monitoring
        fi
        if [ -d "/opt/app-mobile" ]; then
            tar -czf ~/$backup_dir/app-mobile-config.tar.gz /opt/app-mobile
        fi

        # Sauvegarder les volumes Docker
        echo "[INFO] Sauvegarde des volumes Docker..."
        volumes=\$(sudo docker volume ls -q)
        if [ -n "\$volumes" ]; then
            mkdir -p ~/$backup_dir/volumes
            for volume in \$volumes; do
                echo "[INFO] Sauvegarde du volume \$volume..."
                # Créer un conteneur temporaire pour accéder au volume
                sudo docker run --rm -v \$volume:/source -v ~/$backup_dir/volumes:/backup alpine tar -czf /backup/\$volume.tar.gz -C /source .
            done
        else
            echo "[INFO] Aucun volume Docker à sauvegarder."
        fi

        # Sauvegarder les logs des conteneurs
        echo "[INFO] Sauvegarde des logs des conteneurs..."
        containers=\$(sudo docker ps -a --format "{{.Names}}")
        if [ -n "\$containers" ]; then
            mkdir -p ~/$backup_dir/logs
            for container in \$containers; do
                echo "[INFO] Sauvegarde des logs du conteneur \$container..."
                sudo docker logs \$container > ~/$backup_dir/logs/\$container.log 2>&1
            done
        else
            echo "[INFO] Aucun conteneur à sauvegarder."
        fi

        # Sauvegarder les images Docker
        echo "[INFO] Sauvegarde des informations sur les images Docker..."
        sudo docker images > ~/$backup_dir/docker-images.txt

        # Sauvegarder les configurations des conteneurs
        echo "[INFO] Sauvegarde des configurations des conteneurs..."
        containers=\$(sudo docker ps -a --format "{{.Names}}")
        if [ -n "\$containers" ]; then
            mkdir -p ~/$backup_dir/configs
            for container in \$containers; do
                echo "[INFO] Sauvegarde de la configuration du conteneur \$container..."
                sudo docker inspect \$container > ~/$backup_dir/configs/\$container.json
            done
        fi

        # Compresser le répertoire de sauvegarde
        echo "[INFO] Compression du répertoire de sauvegarde..."
        tar -czf ~/$backup_dir.tar.gz -C ~ $backup_dir
        rm -rf ~/$backup_dir

        # Installer AWS CLI si nécessaire
        if ! command -v aws &> /dev/null; then
            echo "[INFO] Installation de AWS CLI..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
        fi

        # Uploader la sauvegarde vers S3
        echo "[INFO] Upload de la sauvegarde vers S3..."
        aws s3 cp ~/$backup_dir.tar.gz s3://$s3_bucket/$backup_dir.tar.gz

        # Supprimer le fichier de sauvegarde local
        echo "[INFO] Suppression du fichier de sauvegarde local..."
        rm -f ~/$backup_dir.tar.gz

        echo "[INFO] Sauvegarde terminée et uploadée vers S3: s3://$s3_bucket/$backup_dir.tar.gz"
EOF
}

# Fonction pour restaurer les données des conteneurs
restore_containers() {
    local ip=$1
    local instance_type=$2
    local s3_bucket=$3
    
    echo -e "\n[INFO] Restauration des données des conteneurs sur l'instance $instance_type ($ip)..."
    
    # Se connecter à l'instance EC2 et restaurer les données
    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no ec2-user@$ip << EOF
        # Installer AWS CLI si nécessaire
        if ! command -v aws &> /dev/null; then
            echo "[INFO] Installation de AWS CLI..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
        fi

        # Lister les sauvegardes disponibles
        echo "[INFO] Liste des sauvegardes disponibles pour $instance_type..."
        backups=\$(aws s3 ls s3://$s3_bucket/ | grep "yourmedia-backup-$instance_type" | sort -r)
        
        if [ -z "\$backups" ]; then
            echo "[ERROR] Aucune sauvegarde trouvée pour $instance_type dans le bucket S3."
            exit 1
        fi
        
        # Afficher les sauvegardes disponibles
        echo "\$backups"
        
        # Demander à l'utilisateur de choisir une sauvegarde
        echo "[PROMPT] Entrez le nom complet du fichier de sauvegarde à restaurer:"
        read backup_file
        
        if [ -z "\$backup_file" ]; then
            echo "[ERROR] Aucun fichier de sauvegarde spécifié."
            exit 1
        fi
        
        # Télécharger la sauvegarde depuis S3
        echo "[INFO] Téléchargement de la sauvegarde depuis S3..."
        aws s3 cp s3://$s3_bucket/\$backup_file ~/\$backup_file
        
        # Extraire la sauvegarde
        echo "[INFO] Extraction de la sauvegarde..."
        mkdir -p ~/restore
        tar -xzf ~/\$backup_file -C ~/restore
        
        # Trouver le répertoire de sauvegarde
        backup_dir=\$(find ~/restore -type d -name "yourmedia-backup-*" | head -1)
        
        if [ -z "\$backup_dir" ]; then
            echo "[ERROR] Impossible de trouver le répertoire de sauvegarde dans l'archive."
            rm -rf ~/restore ~/\$backup_file
            exit 1
        fi
        
        # Restaurer les configurations Docker
        echo "[INFO] Restauration des configurations Docker..."
        if [ -f "\$backup_dir/monitoring-config.tar.gz" ]; then
            echo "[INFO] Restauration des configurations de monitoring..."
            sudo tar -xzf \$backup_dir/monitoring-config.tar.gz -C /
        fi
        
        if [ -f "\$backup_dir/app-mobile-config.tar.gz" ]; then
            echo "[INFO] Restauration des configurations d'application mobile..."
            sudo tar -xzf \$backup_dir/app-mobile-config.tar.gz -C /
        fi
        
        # Restaurer les volumes Docker
        echo "[INFO] Restauration des volumes Docker..."
        if [ -d "\$backup_dir/volumes" ]; then
            for volume_file in \$backup_dir/volumes/*.tar.gz; do
                if [ -f "\$volume_file" ]; then
                    volume_name=\$(basename \$volume_file .tar.gz)
                    echo "[INFO] Restauration du volume \$volume_name..."
                    
                    # Vérifier si le volume existe déjà
                    if ! sudo docker volume inspect \$volume_name &>/dev/null; then
                        echo "[INFO] Création du volume \$volume_name..."
                        sudo docker volume create \$volume_name
                    else
                        echo "[INFO] Le volume \$volume_name existe déjà."
                    fi
                    
                    # Restaurer les données du volume
                    sudo docker run --rm -v \$volume_name:/target -v \$volume_file:/backup.tar.gz alpine sh -c "tar -xzf /backup.tar.gz -C /target"
                fi
            done
        else
            echo "[INFO] Aucun volume à restaurer."
        fi
        
        # Nettoyer
        echo "[INFO] Nettoyage des fichiers temporaires..."
        rm -rf ~/restore ~/\$backup_file
        
        echo "[INFO] Restauration terminée. Redémarrez les conteneurs pour appliquer les changements."
EOF
}

# Exécuter l'action demandée
if [ "$ACTION" = "backup" ]; then
    # Demander confirmation avant de procéder
    echo -e "\n[WARN] Vous êtes sur le point de sauvegarder les données des conteneurs Docker sur les instances suivantes:"
    echo "  - Instance de monitoring: $EC2_MONITORING_IP"
    echo "  - Instance d'application: $EC2_APP_IP"
    echo "  - Bucket S3: $S3_BUCKET"
    read -p $'\n[PROMPT] Êtes-vous sûr de vouloir continuer? (y/n): ' -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] Opération annulée."
        exit 0
    fi
    
    # Sauvegarder les conteneurs sur l'instance de monitoring
    backup_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
    
    # Sauvegarder les conteneurs sur l'instance d'application
    backup_containers $EC2_APP_IP "app" $S3_BUCKET
    
    echo -e "\n[SUCCESS] Sauvegarde des conteneurs Docker terminée sur toutes les instances."
elif [ "$ACTION" = "restore" ]; then
    # Demander confirmation avant de procéder
    echo -e "\n[WARN] Vous êtes sur le point de restaurer les données des conteneurs Docker sur les instances suivantes:"
    echo "  - Instance de monitoring: $EC2_MONITORING_IP"
    echo "  - Instance d'application: $EC2_APP_IP"
    echo "  - Bucket S3: $S3_BUCKET"
    echo -e "\n[WARN] Cette opération peut écraser des données existantes. Assurez-vous d'avoir arrêté les conteneurs avant de continuer."
    read -p $'\n[PROMPT] Êtes-vous sûr de vouloir continuer? (y/n): ' -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] Opération annulée."
        exit 0
    fi
    
    # Restaurer les conteneurs sur l'instance de monitoring
    restore_containers $EC2_MONITORING_IP "monitoring" $S3_BUCKET
    
    # Restaurer les conteneurs sur l'instance d'application
    restore_containers $EC2_APP_IP "app" $S3_BUCKET
    
    echo -e "\n[SUCCESS] Restauration des conteneurs Docker terminée sur toutes les instances."
fi
