#!/bin/bash
# Script pour vérifier l'état des conteneurs et afficher les informations de connexion
# Auteur: Med3Sin
# Date: $(date +%Y-%m-%d)

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || {
            log "ERREUR: Impossible d'installer $pkg"
            exit 1
        }
    fi
}

check_dependency docker docker
check_dependency curl curl
check_dependency jq jq

# Récupérer l'adresse IP publique de l'instance
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="localhost"
    log "AVERTISSEMENT: Impossible de récupérer l'adresse IP publique. Utilisation de 'localhost'."
fi

# Vérifier l'état des conteneurs
log "Vérification de l'état des conteneurs..."
CONTAINERS=$(docker ps --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    log "AVERTISSEMENT: Aucun conteneur n'est en cours d'exécution."
    log "Tentative de démarrage des conteneurs..."

    if [ -f "/opt/monitoring/docker-compose.yml" ]; then
        cd /opt/monitoring
        sudo docker-compose up -d
        sleep 5
        CONTAINERS=$(docker ps --format "{{.Names}}")

        if [ -z "$CONTAINERS" ]; then
            log "ERREUR: Impossible de démarrer les conteneurs."
            exit 1
        fi
    else
        log "ERREUR: Le fichier docker-compose.yml n'existe pas."
        exit 1
    fi
fi

# Liste des conteneurs attendus
EXPECTED_CONTAINERS=("prometheus" "grafana" "sonarqube" "sonarqube-db" "mysql-exporter" "cloudwatch-exporter" "node-exporter")

# Vérifier chaque conteneur
for container in "${EXPECTED_CONTAINERS[@]}"; do
    if ! docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        log "Le conteneur $container n'est pas en cours d'exécution. Tentative de redémarrage..."

        # Vérifier si le conteneur existe
        if docker ps -a --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            # Le conteneur existe mais n'est pas en cours d'exécution
            log "Redémarrage du conteneur $container..."
            docker start $container

            # Vérifier si le redémarrage a réussi
            if ! docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
                log "ERREUR: Impossible de redémarrer le conteneur $container."

                # Afficher les logs du conteneur
                log "Logs du conteneur $container:"
                docker logs --tail 20 $container

                # Si c'est SonarQube, vérifier les prérequis système
                if [ "$container" = "sonarqube" ]; then
                    log "Vérification des prérequis système pour SonarQube..."

                    # Vérifier la valeur de vm.max_map_count
                    current_max_map_count=$(sysctl -n vm.max_map_count)
                    if [ "$current_max_map_count" -lt 262144 ]; then
                        log "La valeur de vm.max_map_count est trop basse: $current_max_map_count. Augmentation à 262144..."
                        sudo sysctl -w vm.max_map_count=262144
                        echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf
                        sudo sysctl --system
                    fi

                    # Recréer le conteneur avec des limites de mémoire plus élevées
                    log "Recréation du conteneur SonarQube..."
                    cd /opt/monitoring
                    sudo docker-compose up -d sonarqube
                fi

                # Si c'est MySQL Exporter, vérifier la configuration
                if [ "$container" = "mysql-exporter" ]; then
                    log "Vérification de la configuration de MySQL Exporter..."

                    # Vérifier si les variables RDS sont définies
                    if [ -f "/opt/monitoring/aws-resources.env" ]; then
                        source /opt/monitoring/aws-resources.env
                    fi

                    if [ -z "$RDS_USERNAME" ] || [ -z "$RDS_PASSWORD" ] || [ -z "$RDS_ENDPOINT" ]; then
                        log "ERREUR: Les variables RDS ne sont pas définies correctement."
                    else
                        # Extraire l'hôte et le port de RDS_ENDPOINT
                        if [[ "$RDS_ENDPOINT" == *":"* ]]; then
                            RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d':' -f1)
                            RDS_PORT=$(echo "$RDS_ENDPOINT" | cut -d':' -f2)
                        else
                            RDS_HOST="$RDS_ENDPOINT"
                            RDS_PORT="3306"
                        fi

                        # Créer un fichier .my.cnf temporaire
                        log "Création d'un fichier .my.cnf temporaire..."
                        cat > /tmp/.my.cnf << EOF
[client]
user=${RDS_USERNAME}
password=${RDS_PASSWORD}
host=${RDS_HOST}
port=${RDS_PORT}
EOF
                        chmod 600 /tmp/.my.cnf

                        # Recréer le conteneur MySQL Exporter
                        log "Recréation du conteneur MySQL Exporter..."
                        cd /opt/monitoring
                        sudo docker-compose up -d mysql-exporter
                    fi
                fi
            else
                log "Le conteneur $container a été redémarré avec succès."
            fi
        else
            # Le conteneur n'existe pas
            log "Le conteneur $container n'existe pas. Tentative de création..."
            cd /opt/monitoring
            sudo docker-compose up -d $container
        fi
    else
        log "Le conteneur $container est en cours d'exécution."
    fi
done

# Afficher les conteneurs en cours d'exécution
log "Conteneurs en cours d'exécution:"
docker ps

# Vérifier si les services sont accessibles
check_service() {
    local service=$1
    local port=$2
    local url="http://$PUBLIC_IP:$port"

    log "Vérification de l'accès à $service ($url)..."
    if curl -s --head --fail "$url" > /dev/null; then
        log "$service est accessible à l'adresse $url"
        return 0
    else
        log "AVERTISSEMENT: $service n'est pas accessible à l'adresse $url"
        return 1
    fi
}

# Vérifier les services
check_service "Grafana" "3000"
check_service "Prometheus" "9090"
check_service "SonarQube" "9000"

# Afficher les informations de connexion
log "Informations de connexion:"
log "- Grafana: http://$PUBLIC_IP:3000 (utilisateur: admin, mot de passe: défini dans les variables d'environnement)"
log "- Prometheus: http://$PUBLIC_IP:9090"
log "- SonarQube: http://$PUBLIC_IP:9000 (utilisateur: admin, mot de passe: admin)"

# Afficher les informations sur les ressources AWS
if [ -f "/opt/monitoring/aws-resources.env" ]; then
    log "Chargement des informations sur les ressources AWS..."
    source /opt/monitoring/aws-resources.env

    log "Informations sur les ressources AWS:"
    log "- RDS Endpoint: $RDS_ENDPOINT"
    log "- S3 Bucket: $S3_BUCKET_NAME"
    log "- AWS Region: $AWS_REGION"
else
    log "AVERTISSEMENT: Le fichier aws-resources.env n'existe pas."
fi

# Afficher l'utilisation des ressources
log "Utilisation des ressources:"
log "- CPU:"
top -bn1 | head -n 5

log "- Mémoire:"
free -h

log "- Disque:"
df -h

exit 0
