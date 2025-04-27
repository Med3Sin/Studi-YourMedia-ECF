#!/bin/bash
# Script simplifié d'initialisation pour l'instance EC2 de monitoring avec variables d'environnement

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérification des variables d'environnement requises
# Récupérer la variable S3_BUCKET_NAME depuis les métadonnées de l'instance si elle n'est pas définie
if [ -z "$S3_BUCKET_NAME" ]; then
    log "La variable S3_BUCKET_NAME n'est pas définie, tentative de récupération depuis les métadonnées de l'instance..."
    # Récupérer les tags de l'instance
    INSTANCE_ID=$(curl -s --connect-timeout 5 --retry 3 http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s --connect-timeout 5 --retry 3 http://169.254.169.254/latest/meta-data/placement/region)

    if [ -z "$INSTANCE_ID" ] || [ -z "$REGION" ]; then
        log "AVERTISSEMENT: Impossible de récupérer l'ID de l'instance ou la région depuis les métadonnées"
        log "Utilisation des valeurs par défaut"
        S3_BUCKET_NAME="yourmedia-ecf-studi"
    else
        # Récupérer le tag S3_BUCKET_NAME
        S3_BUCKET_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=S3_BUCKET_NAME" --query "Tags[0].Value" --output text 2>/dev/null || echo "")

        if [ -z "${S3_BUCKET_NAME}" ] || [ "${S3_BUCKET_NAME}" = "None" ]; then
            log "AVERTISSEMENT: Impossible de récupérer la variable S3_BUCKET_NAME depuis les métadonnées de l'instance"
            log "Utilisation de la valeur par défaut"
            S3_BUCKET_NAME="yourmedia-ecf-studi"
        else
            log "Variable S3_BUCKET_NAME récupérée depuis les métadonnées de l'instance: ${S3_BUCKET_NAME}"
        fi
    fi

    # Exporter la variable pour les scripts suivants
    export S3_BUCKET_NAME
fi

# Vérifier si le bucket S3 existe
if ! aws s3 ls s3://${S3_BUCKET_NAME} &>/dev/null; then
    log "AVERTISSEMENT: Le bucket S3 ${S3_BUCKET_NAME} n'existe pas ou n'est pas accessible"
    log "Les scripts seront créés localement"
    BUCKET_EXISTS=false
else
    log "Le bucket S3 ${S3_BUCKET_NAME} existe et est accessible"
    BUCKET_EXISTS=true
fi

# Vérification des dépendances
check_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v $cmd &> /dev/null; then
        log "Dépendance manquante: $cmd. Installation de $pkg..."
        sudo dnf install -y $pkg || error_exit "Impossible d'installer $pkg"
    fi
}

# Création du répertoire de monitoring
log "Création du répertoire de monitoring"
sudo mkdir -p /opt/monitoring

# Configuration des clés SSH
log "Configuration des clés SSH"
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Récupération de la clé publique depuis les métadonnées
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
fi
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

# Vérification des dépendances essentielles
log "Vérification des dépendances essentielles"
check_dependency aws aws-cli
check_dependency curl curl
check_dependency sed sed

# Afficher les variables d'environnement pour le débogage
log "Variables d'environnement:"
log "S3_BUCKET_NAME=$S3_BUCKET_NAME"
log "EC2_INSTANCE_PRIVATE_IP=$EC2_INSTANCE_PRIVATE_IP"

# Téléchargement des scripts depuis S3 ou création de scripts par défaut
log "Téléchargement des scripts depuis S3 ou création de scripts par défaut"

if [ "$BUCKET_EXISTS" = true ]; then
    log "Utilisation du bucket S3: ${S3_BUCKET_NAME}"

    # Télécharger les scripts essentiels avec gestion d'erreur
    download_script() {
        local source_path=$1
        local dest_path=$2
        local is_required=$3
        local default_script=$4

        log "Téléchargement de $source_path vers $dest_path"
        if sudo aws s3 cp s3://${S3_BUCKET_NAME}/$source_path $dest_path; then
            log "Téléchargement réussi: $source_path"
            return 0
        else
            log "AVERTISSEMENT: Impossible de télécharger $source_path depuis S3"
            if [ "$is_required" = true ] && [ -n "$default_script" ]; then
                log "Création d'un script par défaut pour $dest_path"
                echo "$default_script" | sudo tee $dest_path > /dev/null
                sudo chmod +x $dest_path
                return 0
            elif [ "$is_required" = true ]; then
                error_exit "Impossible de télécharger le script requis $source_path"
                return 1
            else
                return 1
            fi
        fi
    }

    # Script setup.sh par défaut
    SETUP_SCRIPT='#!/bin/bash
# Script de configuration par défaut
echo "Installation des conteneurs Docker pour le monitoring..."
# Installer Docker si nécessaire
if ! command -v docker &> /dev/null; then
    echo "Installation de Docker..."
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
fi
# Démarrer les conteneurs
cd /opt/monitoring
if [ -f "docker-compose.yml" ]; then
    sudo docker-compose up -d
else
    echo "ERREUR: docker-compose.yml introuvable"
    exit 1
fi
echo "Installation terminée"
'

    # Script install-docker.sh par défaut
    INSTALL_DOCKER_SCRIPT='#!/bin/bash
# Script d'\''installation Docker par défaut
echo "Installation de Docker..."
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
echo "Docker installé avec succès"
'

    # Script fix_permissions.sh par défaut
    FIX_PERMISSIONS_SCRIPT='#!/bin/bash
# Script de correction des permissions par défaut
echo "Correction des permissions..."
sudo chown -R ec2-user:ec2-user /opt/monitoring
sudo chmod -R 755 /opt/monitoring
echo "Permissions corrigées"
'

    # Script docker-manager.sh par défaut
    DOCKER_MANAGER_SCRIPT='#!/bin/bash
# Script de gestion Docker par défaut
ACTION=$1
TARGET=$2

if [ "$ACTION" = "deploy" ] && [ "$TARGET" = "monitoring" ]; then
    echo "Déploiement des conteneurs de monitoring..."
    cd /opt/monitoring
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
    else
        echo "ERREUR: docker-compose.yml introuvable"
        exit 1
    fi
elif [ "$ACTION" = "stop" ] && [ "$TARGET" = "monitoring" ]; then
    echo "Arrêt des conteneurs de monitoring..."
    cd /opt/monitoring
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
    else
        echo "ERREUR: docker-compose.yml introuvable"
        exit 1
    fi
else
    echo "Usage: $0 {deploy|stop} monitoring"
    exit 1
fi
'

    # Télécharger les scripts essentiels
    download_script "scripts/ec2-monitoring/setup.sh" "/opt/monitoring/setup.sh" true "$SETUP_SCRIPT"
    download_script "scripts/ec2-monitoring/install-docker.sh" "/opt/monitoring/install-docker.sh" true "$INSTALL_DOCKER_SCRIPT"
    download_script "scripts/ec2-monitoring/fix_permissions.sh" "/opt/monitoring/fix_permissions.sh" true "$FIX_PERMISSIONS_SCRIPT"
    download_script "scripts/docker/docker-manager.sh" "/opt/monitoring/docker-manager.sh" true "$DOCKER_MANAGER_SCRIPT"

    # Télécharger les scripts optionnels
    download_script "scripts/ec2-monitoring/get-aws-resources-info.sh" "/opt/monitoring/get-aws-resources-info.sh" false

    # Télécharger le fichier docker-compose.yml
    if ! download_script "scripts/docker/monitoring/docker-compose.yml" "/opt/monitoring/docker-compose.yml.template" false; then
        log "Tentative de téléchargement du docker-compose.yml spécifique à l'instance"
        download_script "scripts/ec2-monitoring/docker-compose.yml" "/opt/monitoring/docker-compose.yml.template" false
    fi

    # Télécharger les fichiers de configuration
    download_script "scripts/ec2-monitoring/cloudwatch-config.yml" "/opt/monitoring/cloudwatch-config.yml" false
    download_script "scripts/ec2-monitoring/configure-sonarqube.sh" "/opt/monitoring/configure-sonarqube.sh" false
else
    log "Le bucket S3 n'est pas accessible, création de scripts par défaut"

    # Créer les scripts par défaut
    sudo bash -c 'cat > /opt/monitoring/setup.sh << "EOF"
#!/bin/bash
# Script de configuration par défaut
echo "Installation des conteneurs Docker pour le monitoring..."
# Installer Docker si nécessaire
if ! command -v docker &> /dev/null; then
    echo "Installation de Docker..."
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
fi
# Démarrer les conteneurs
cd /opt/monitoring
if [ -f "docker-compose.yml" ]; then
    sudo docker-compose up -d
else
    echo "ERREUR: docker-compose.yml introuvable"
    exit 1
fi
echo "Installation terminée"
EOF'

    sudo bash -c 'cat > /opt/monitoring/install-docker.sh << "EOF"
#!/bin/bash
# Script d'\''installation Docker par défaut
echo "Installation de Docker..."
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
echo "Docker installé avec succès"
EOF'

    sudo bash -c 'cat > /opt/monitoring/fix_permissions.sh << "EOF"
#!/bin/bash
# Script de correction des permissions par défaut
echo "Correction des permissions..."
sudo chown -R ec2-user:ec2-user /opt/monitoring
sudo chmod -R 755 /opt/monitoring
echo "Permissions corrigées"
EOF'

    sudo bash -c 'cat > /opt/monitoring/docker-manager.sh << "EOF"
#!/bin/bash
# Script de gestion Docker par défaut
ACTION=$1
TARGET=$2

if [ "$ACTION" = "deploy" ] && [ "$TARGET" = "monitoring" ]; then
    echo "Déploiement des conteneurs de monitoring..."
    cd /opt/monitoring
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
    else
        echo "ERREUR: docker-compose.yml introuvable"
        exit 1
    fi
elif [ "$ACTION" = "stop" ] && [ "$TARGET" = "monitoring" ]; then
    echo "Arrêt des conteneurs de monitoring..."
    cd /opt/monitoring
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
    else
        echo "ERREUR: docker-compose.yml introuvable"
        exit 1
    fi
else
    echo "Usage: $0 {deploy|stop} monitoring"
    exit 1
fi
EOF'

    # Créer un fichier docker-compose.yml par défaut
    sudo bash -c 'cat > /opt/monitoring/docker-compose.yml.template << "EOF"
version: "3"

services:
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /opt/monitoring/prometheus-data:/prometheus
    restart: always

  grafana:
    image: grafana/grafana:10.0.3
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - /opt/monitoring/grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}
    restart: always

  sonarqube:
    image: sonarqube:9.9-community
    container_name: sonarqube
    ports:
      - "9000:9000"
    volumes:
      - /opt/monitoring/sonarqube-data/data:/opt/sonarqube/data
      - /opt/monitoring/sonarqube-data/logs:/opt/sonarqube/logs
      - /opt/monitoring/sonarqube-data/extensions:/opt/sonarqube/extensions
    environment:
      - SONAR_JDBC_URL=jdbc:h2:tcp://localhost:9092/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
    restart: always
EOF'

    # Créer un fichier prometheus.yml par défaut
    sudo bash -c 'cat > /opt/monitoring/prometheus.yml << "EOF"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
EOF'
fi

# Rendre les scripts exécutables
sudo chmod +x /opt/monitoring/install-docker.sh
sudo chmod +x /opt/monitoring/setup.sh
sudo chmod +x /opt/monitoring/fix_permissions.sh
sudo chmod +x /opt/monitoring/docker-manager.sh
if [ -f "/opt/monitoring/get-aws-resources-info.sh" ]; then
    sudo chmod +x /opt/monitoring/get-aws-resources-info.sh
fi
if [ -f "/opt/monitoring/configure-sonarqube.sh" ]; then
    sudo chmod +x /opt/monitoring/configure-sonarqube.sh
fi

# Copier docker-manager.sh dans /usr/local/bin/
log "Copie de docker-manager.sh dans /usr/local/bin/"
sudo cp /opt/monitoring/docker-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-manager.sh

# Création d'un fichier de variables d'environnement pour les scripts
log "Création du fichier de variables d'environnement"

# Extraire l'hôte et le port de RDS_ENDPOINT
if [[ "${RDS_ENDPOINT}" == *":"* ]]; then
    RDS_HOST=$(echo "${RDS_ENDPOINT}" | cut -d':' -f1)
    RDS_PORT=$(echo "${RDS_ENDPOINT}" | cut -d':' -f2)
else
    RDS_HOST="${RDS_ENDPOINT}"
    RDS_PORT="3306"
fi

# Créer un répertoire sécurisé pour les variables d'environnement
sudo mkdir -p /opt/monitoring/secure
sudo chmod 700 /opt/monitoring/secure

# Créer un fichier pour les variables non sensibles
cat > /tmp/monitoring-env.sh << EOF
export EC2_INSTANCE_PRIVATE_IP="${EC2_INSTANCE_PRIVATE_IP}"
# Variables RDS standardisées (références sécurisées)
export RDS_USERNAME="\$(cat /opt/monitoring/secure/rds_username.txt 2>/dev/null || echo "${RDS_USERNAME}")"
export RDS_ENDPOINT="\$(cat /opt/monitoring/secure/rds_endpoint.txt 2>/dev/null || echo "${RDS_ENDPOINT}")"
export RDS_HOST="\$(cat /opt/monitoring/secure/rds_host.txt 2>/dev/null || echo "${RDS_HOST}")"
export RDS_PORT="\$(cat /opt/monitoring/secure/rds_port.txt 2>/dev/null || echo "${RDS_PORT}")"
# Variables de compatibilité (pour les scripts existants)
export DB_USERNAME="\$RDS_USERNAME"
# Variables SonarQube (références sécurisées)
export SONAR_JDBC_USERNAME="\$(cat /opt/monitoring/secure/sonar_jdbc_username.txt 2>/dev/null || echo "${SONAR_JDBC_USERNAME}")"
export SONAR_JDBC_URL="\$(cat /opt/monitoring/secure/sonar_jdbc_url.txt 2>/dev/null || echo "${SONAR_JDBC_URL}")"
# Variables S3
export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
# Variables Docker Hub (références sécurisées)
export DOCKERHUB_USERNAME="\$(cat /opt/monitoring/secure/dockerhub_username.txt 2>/dev/null || echo "${DOCKERHUB_USERNAME}")"
export DOCKER_USERNAME="\$DOCKERHUB_USERNAME"
export DOCKER_REPO="\$(cat /opt/monitoring/secure/docker_repo.txt 2>/dev/null || echo "${DOCKER_REPO:-yourmedia-ecf}")"
# Charger les variables sensibles
source /opt/monitoring/secure/sensitive-env.sh 2>/dev/null || true
EOF

# Créer un fichier pour les variables sensibles
cat > /tmp/sensitive-env.sh << EOF
# Variables sensibles
export RDS_PASSWORD="${RDS_PASSWORD}"
export DB_PASSWORD="\$RDS_PASSWORD"
export SONAR_JDBC_PASSWORD="${SONAR_JDBC_PASSWORD}"
export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-YourMedia2025!}"
export GF_SECURITY_ADMIN_PASSWORD="\$GRAFANA_ADMIN_PASSWORD"
export DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN}"
EOF

# Déplacer les fichiers vers leurs emplacements définitifs
sudo mv /tmp/monitoring-env.sh /opt/monitoring/env.sh
sudo mv /tmp/sensitive-env.sh /opt/monitoring/secure/sensitive-env.sh

# Définir les permissions appropriées
sudo chmod +x /opt/monitoring/env.sh
sudo chmod 600 /opt/monitoring/secure/sensitive-env.sh

# Stocker les variables non sensibles dans des fichiers séparés pour une meilleure sécurité
echo "${RDS_USERNAME}" | sudo tee /opt/monitoring/secure/rds_username.txt > /dev/null
echo "${RDS_ENDPOINT}" | sudo tee /opt/monitoring/secure/rds_endpoint.txt > /dev/null
echo "${RDS_HOST}" | sudo tee /opt/monitoring/secure/rds_host.txt > /dev/null
echo "${RDS_PORT}" | sudo tee /opt/monitoring/secure/rds_port.txt > /dev/null
echo "${SONAR_JDBC_USERNAME}" | sudo tee /opt/monitoring/secure/sonar_jdbc_username.txt > /dev/null
echo "${SONAR_JDBC_URL}" | sudo tee /opt/monitoring/secure/sonar_jdbc_url.txt > /dev/null
echo "${DOCKERHUB_USERNAME}" | sudo tee /opt/monitoring/secure/dockerhub_username.txt > /dev/null
echo "${DOCKER_REPO:-yourmedia-ecf}" | sudo tee /opt/monitoring/secure/docker_repo.txt > /dev/null

# Sécuriser les fichiers
sudo chmod 600 /opt/monitoring/secure/*.txt

# Modification du script setup.sh pour utiliser les variables d'environnement
log "Modification du script setup.sh pour utiliser les variables d'environnement"
sudo sed -i '1s|^|#!/bin/bash\nsource /opt/monitoring/env.sh\n\n|' /opt/monitoring/setup.sh

# Installation de Docker
log "Vérification de l'installation de Docker"
if command -v docker &> /dev/null; then
    log "Docker est déjà installé, version: $(docker --version)"

    # Vérifier si le service Docker est en cours d'exécution
    if ! systemctl is-active --quiet docker; then
        log "Le service Docker n'est pas en cours d'exécution, démarrage..."
        sudo systemctl start docker || log "AVERTISSEMENT: Impossible de démarrer le service Docker"
    fi

    # Vérifier si le service Docker est activé au démarrage
    if ! systemctl is-enabled --quiet docker; then
        log "Le service Docker n'est pas activé au démarrage, activation..."
        sudo systemctl enable docker || log "AVERTISSEMENT: Impossible d'activer le service Docker au démarrage"
    fi
else
    log "Docker n'est pas installé. Installation via le script..."
    if [ -f "/opt/monitoring/install-docker.sh" ]; then
        # Exécuter le script d'installation avec capture de la sortie
        log "Exécution du script install-docker.sh..."
        if sudo /opt/monitoring/install-docker.sh > /var/log/docker-install.log 2>&1; then
            log "Installation de Docker réussie via le script"
        else
            log "AVERTISSEMENT: L'installation via le script a échoué, tentative d'installation manuelle..."
            sudo dnf update -y
            sudo dnf install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker ec2-user
        fi
    else
        log "Le script install-docker.sh n'existe pas, installation manuelle..."
        sudo dnf update -y
        sudo dnf install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ec2-user
    fi

    # Vérifier l'installation
    if command -v docker &> /dev/null; then
        log "Docker est installé avec succès, version: $(docker --version)"
    else
        log "AVERTISSEMENT: L'installation de Docker a échoué, poursuite de l'initialisation..."
    fi
fi

# Installation de Docker Compose
log "Vérification de l'installation de Docker Compose"
if command -v docker-compose &> /dev/null; then
    log "Docker Compose est déjà installé, version: $(docker-compose --version)"
else
    log "Installation de Docker Compose..."
    COMPOSE_VERSION="v2.20.3"

    # Créer le répertoire /usr/local/bin s'il n'existe pas
    sudo mkdir -p /usr/local/bin

    # Télécharger Docker Compose avec retry
    MAX_RETRIES=3
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if sudo curl -L --connect-timeout 30 --retry 5 "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
            log "Docker Compose téléchargé avec succès"
            sudo chmod +x /usr/local/bin/docker-compose
            sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            break
        else
            RETRY_COUNT=$((RETRY_COUNT+1))
            log "Échec du téléchargement de Docker Compose (tentative $RETRY_COUNT/$MAX_RETRIES)"
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                log "AVERTISSEMENT: Impossible de télécharger Docker Compose après $MAX_RETRIES tentatives"
                log "Tentative d'installation via dnf..."
                if sudo dnf list installed docker-compose &>/dev/null || sudo dnf install -y docker-compose; then
                    log "Docker Compose installé via dnf"
                    break
                else
                    log "AVERTISSEMENT: L'installation de Docker Compose a échoué, poursuite de l'initialisation..."
                    break
                fi
            fi
            sleep 5
        fi
    done
fi

# Exécution du script de correction des permissions
log "Exécution du script de correction des permissions"
sudo /opt/monitoring/fix_permissions.sh || log "AVERTISSEMENT: L'exécution du script fix_permissions.sh a échoué."

# Télécharger ou créer le script fix-containers.sh
log "Vérification du script fix-containers.sh"
if [ ! -f "/opt/monitoring/fix-containers.sh" ]; then
    log "Le script fix-containers.sh n'existe pas, tentative de téléchargement depuis S3..."
    if [ "$BUCKET_EXISTS" = true ]; then
        if ! sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/fix-containers.sh /opt/monitoring/fix-containers.sh; then
            log "Impossible de télécharger fix-containers.sh depuis S3, création d'un script par défaut..."
            sudo bash -c 'cat > /opt/monitoring/fix-containers.sh << "EOF"
#!/bin/bash
# Script pour corriger les problèmes des conteneurs Docker de monitoring
# Auteur: Med3Sin

# Fonction de journalisation
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# 1. Corriger le problème de cloudwatch-exporter
log "Correction du problème de cloudwatch-exporter..."
mkdir -p /opt/monitoring/cloudwatch-config
if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
    log "Création du fichier de configuration cloudwatch-config.yml..."
    cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << "EOF2"
---
region: eu-west-3
metrics:
  # Métriques EC2
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      InstanceId: "*"

  # Métriques S3
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average]
    aws_dimension_select:
      BucketName: "*"
      StorageType: "StandardStorage"

  # Métriques RDS
  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      DBInstanceIdentifier: "*"
EOF2
    log "Fichier de configuration cloudwatch-config.yml créé avec succès."
else
    log "Le fichier cloudwatch-config.yml existe déjà."
fi

# Définir les permissions
log "Définition des permissions..."
chmod 644 /opt/monitoring/cloudwatch-config/cloudwatch-config.yml
chown -R ec2-user:ec2-user /opt/monitoring/cloudwatch-config

# 2. Corriger le problème de mysql-exporter
log "Correction du problème de mysql-exporter..."
cat > /opt/monitoring/mysql-exporter-fix.yml << EOF2
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=\${RDS_USERNAME:-yourmedia}:\${RDS_PASSWORD:-password}@tcp(\${RDS_HOST:-localhost}:\${RDS_PORT:-3306})/
    entrypoint:
      - /bin/mysqld_exporter
    command:
      - --web.listen-address=:9104
      - --collect.info_schema.tables
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256
EOF2

# 3. Corriger le problème de SonarQube (Elasticsearch)
log "Correction du problème de SonarQube (Elasticsearch)..."

# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
log "Augmentation de la limite de mmap count..."
sysctl -w vm.max_map_count=262144
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    sed -i "s/vm.max_map_count=.*/vm.max_map_count=262144/" /etc/sysctl.conf
else
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -p

# Augmenter la limite de fichiers ouverts
log "Augmentation de la limite de fichiers ouverts..."
sysctl -w fs.file-max=65536
if grep -q "fs.file-max" /etc/sysctl.conf; then
    sed -i "s/fs.file-max=.*/fs.file-max=65536/" /etc/sysctl.conf
else
    echo "fs.file-max=65536" >> /etc/sysctl.conf
fi
sysctl -p

# Configurer les limites de ressources pour l'utilisateur ec2-user
log "Configuration des limites de ressources pour l'utilisateur ec2-user..."
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 65536" >> /etc/security/limits.conf
    echo "ec2-user hard nofile 65536" >> /etc/security/limits.conf
fi
if ! grep -q "ec2-user.*nproc" /etc/security/limits.conf; then
    echo "ec2-user soft nproc 4096" >> /etc/security/limits.conf
    echo "ec2-user hard nproc 4096" >> /etc/security/limits.conf
fi

# Créer les répertoires pour SonarQube s'ils n'existent pas
log "Création des répertoires pour SonarQube..."
mkdir -p /opt/monitoring/sonarqube-data/data
mkdir -p /opt/monitoring/sonarqube-data/logs
mkdir -p /opt/monitoring/sonarqube-data/extensions
mkdir -p /opt/monitoring/sonarqube-data/db

# Définir les permissions appropriées pour SonarQube
log "Configuration des permissions pour SonarQube..."
chown -R 999:999 /opt/monitoring/sonarqube-data/data
chown -R 999:999 /opt/monitoring/sonarqube-data/logs
chown -R 999:999 /opt/monitoring/sonarqube-data/extensions
chown -R 999:999 /opt/monitoring/sonarqube-data/db
chmod -R 755 /opt/monitoring/sonarqube-data/data
chmod -R 755 /opt/monitoring/sonarqube-data/logs
chmod -R 755 /opt/monitoring/sonarqube-data/extensions
chmod -R 700 /opt/monitoring/sonarqube-data/db

# 4. Mettre à jour le fichier docker-compose.yml
log "Mise à jour du fichier docker-compose.yml..."

# Sauvegarder le fichier original
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    cp /opt/monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml.bak

    # Remplacer la section mysql-exporter dans docker-compose.yml
    log "Remplacement de la section mysql-exporter dans docker-compose.yml..."
    sed -i "/mysql-exporter:/,/cpu_shares: 256/c\\" /opt/monitoring/docker-compose.yml
    sed -i "/mysql-exporter:/d" /opt/monitoring/docker-compose.yml
    cat /opt/monitoring/mysql-exporter-fix.yml >> /opt/monitoring/docker-compose.yml

    # Mettre à jour la section cloudwatch-exporter dans docker-compose.yml
    log "Mise à jour de la section cloudwatch-exporter dans docker-compose.yml..."
    sed -i "/cloudwatch-exporter:/,/cpu_shares: 256/c\\  cloudwatch-exporter:\\n    image: prom/cloudwatch-exporter:latest\\n    container_name: cloudwatch-exporter\\n    ports:\\n      - \\"9106:9106\\"\\n    volumes:\\n      - /opt/monitoring/cloudwatch-config:/config\\n    command:\\n      - --config.file=/config/cloudwatch-config.yml\\n    restart: always\\n    logging:\\n      driver: \\"json-file\\"\\n      options:\\n        max-size: \\"10m\\"\\n        max-file: \\"3\\"\\n    mem_limit: 256m\\n    cpu_shares: 256" /opt/monitoring/docker-compose.yml

    # Mettre à jour la section sonarqube dans docker-compose.yml pour réduire la mémoire initiale d'Elasticsearch
    log "Mise à jour de la section sonarqube dans docker-compose.yml..."
    sed -i "s/SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m/SONAR_ES_JAVA_OPTS=-Xms256m -Xmx512m/" /opt/monitoring/docker-compose.yml
fi

log "Correction des conteneurs terminée avec succès."
EOF'
        fi
    else
        log "Le bucket S3 n'est pas accessible, création d'un script fix-containers.sh par défaut..."
        sudo bash -c 'cat > /opt/monitoring/fix-containers.sh << "EOF"
#!/bin/bash
# Script pour corriger les problèmes des conteneurs Docker de monitoring
# Auteur: Med3Sin

# Fonction de journalisation
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Vérifier si le script est exécuté avec les privilèges root
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script doit être exécuté avec les privilèges root (sudo)."
    exit 1
fi

# 1. Corriger le problème de cloudwatch-exporter
log "Correction du problème de cloudwatch-exporter..."
mkdir -p /opt/monitoring/cloudwatch-config
if [ ! -f "/opt/monitoring/cloudwatch-config/cloudwatch-config.yml" ]; then
    log "Création du fichier de configuration cloudwatch-config.yml..."
    cat > /opt/monitoring/cloudwatch-config/cloudwatch-config.yml << "EOF2"
---
region: eu-west-3
metrics:
  # Métriques EC2
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [InstanceId]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      InstanceId: "*"

  # Métriques S3
  - aws_namespace: AWS/S3
    aws_metric_name: BucketSizeBytes
    aws_dimensions: [BucketName, StorageType]
    aws_statistics: [Average]
    aws_dimension_select:
      BucketName: "*"
      StorageType: "StandardStorage"

  # Métriques RDS
  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    aws_dimension_select:
      DBInstanceIdentifier: "*"
EOF2
    log "Fichier de configuration cloudwatch-config.yml créé avec succès."
else
    log "Le fichier cloudwatch-config.yml existe déjà."
fi

# Définir les permissions
log "Définition des permissions..."
chmod 644 /opt/monitoring/cloudwatch-config/cloudwatch-config.yml
chown -R ec2-user:ec2-user /opt/monitoring/cloudwatch-config

# 2. Corriger le problème de mysql-exporter
log "Correction du problème de mysql-exporter..."
cat > /opt/monitoring/mysql-exporter-fix.yml << EOF2
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.0
    container_name: mysql-exporter
    ports:
      - "9104:9104"
    environment:
      - DATA_SOURCE_NAME=\${RDS_USERNAME:-yourmedia}:\${RDS_PASSWORD:-password}@tcp(\${RDS_HOST:-localhost}:\${RDS_PORT:-3306})/
    entrypoint:
      - /bin/mysqld_exporter
    command:
      - --web.listen-address=:9104
      - --collect.info_schema.tables
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    mem_limit: 256m
    cpu_shares: 256
EOF2

# 3. Corriger le problème de SonarQube (Elasticsearch)
log "Correction du problème de SonarQube (Elasticsearch)..."

# Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
log "Augmentation de la limite de mmap count..."
sysctl -w vm.max_map_count=262144
if grep -q "vm.max_map_count" /etc/sysctl.conf; then
    sed -i "s/vm.max_map_count=.*/vm.max_map_count=262144/" /etc/sysctl.conf
else
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -p

# Augmenter la limite de fichiers ouverts
log "Augmentation de la limite de fichiers ouverts..."
sysctl -w fs.file-max=65536
if grep -q "fs.file-max" /etc/sysctl.conf; then
    sed -i "s/fs.file-max=.*/fs.file-max=65536/" /etc/sysctl.conf
else
    echo "fs.file-max=65536" >> /etc/sysctl.conf
fi
sysctl -p

# Configurer les limites de ressources pour l'utilisateur ec2-user
log "Configuration des limites de ressources pour l'utilisateur ec2-user..."
if ! grep -q "ec2-user.*nofile" /etc/security/limits.conf; then
    echo "ec2-user soft nofile 65536" >> /etc/security/limits.conf
    echo "ec2-user hard nofile 65536" >> /etc/security/limits.conf
fi
if ! grep -q "ec2-user.*nproc" /etc/security/limits.conf; then
    echo "ec2-user soft nproc 4096" >> /etc/security/limits.conf
    echo "ec2-user hard nproc 4096" >> /etc/security/limits.conf
fi

# Créer les répertoires pour SonarQube s'ils n'existent pas
log "Création des répertoires pour SonarQube..."
mkdir -p /opt/monitoring/sonarqube-data/data
mkdir -p /opt/monitoring/sonarqube-data/logs
mkdir -p /opt/monitoring/sonarqube-data/extensions
mkdir -p /opt/monitoring/sonarqube-data/db

# Définir les permissions appropriées pour SonarQube
log "Configuration des permissions pour SonarQube..."
chown -R 999:999 /opt/monitoring/sonarqube-data/data
chown -R 999:999 /opt/monitoring/sonarqube-data/logs
chown -R 999:999 /opt/monitoring/sonarqube-data/extensions
chown -R 999:999 /opt/monitoring/sonarqube-data/db
chmod -R 755 /opt/monitoring/sonarqube-data/data
chmod -R 755 /opt/monitoring/sonarqube-data/logs
chmod -R 755 /opt/monitoring/sonarqube-data/extensions
chmod -R 700 /opt/monitoring/sonarqube-data/db

# 4. Mettre à jour le fichier docker-compose.yml
log "Mise à jour du fichier docker-compose.yml..."

# Sauvegarder le fichier original
if [ -f "/opt/monitoring/docker-compose.yml" ]; then
    cp /opt/monitoring/docker-compose.yml /opt/monitoring/docker-compose.yml.bak

    # Remplacer la section mysql-exporter dans docker-compose.yml
    log "Remplacement de la section mysql-exporter dans docker-compose.yml..."
    sed -i "/mysql-exporter:/,/cpu_shares: 256/c\\" /opt/monitoring/docker-compose.yml
    sed -i "/mysql-exporter:/d" /opt/monitoring/docker-compose.yml
    cat /opt/monitoring/mysql-exporter-fix.yml >> /opt/monitoring/docker-compose.yml

    # Mettre à jour la section cloudwatch-exporter dans docker-compose.yml
    log "Mise à jour de la section cloudwatch-exporter dans docker-compose.yml..."
    sed -i "/cloudwatch-exporter:/,/cpu_shares: 256/c\\  cloudwatch-exporter:\\n    image: prom/cloudwatch-exporter:latest\\n    container_name: cloudwatch-exporter\\n    ports:\\n      - \\"9106:9106\\"\\n    volumes:\\n      - /opt/monitoring/cloudwatch-config:/config\\n    command:\\n      - --config.file=/config/cloudwatch-config.yml\\n    restart: always\\n    logging:\\n      driver: \\"json-file\\"\\n      options:\\n        max-size: \\"10m\\"\\n        max-file: \\"3\\"\\n    mem_limit: 256m\\n    cpu_shares: 256" /opt/monitoring/docker-compose.yml

    # Mettre à jour la section sonarqube dans docker-compose.yml pour réduire la mémoire initiale d'Elasticsearch
    log "Mise à jour de la section sonarqube dans docker-compose.yml..."
    sed -i "s/SONAR_ES_JAVA_OPTS=-Xms512m -Xmx512m/SONAR_ES_JAVA_OPTS=-Xms256m -Xmx512m/" /opt/monitoring/docker-compose.yml
fi

log "Correction des conteneurs terminée avec succès."
EOF'
    fi

    # Rendre le script exécutable
    sudo chmod +x /opt/monitoring/fix-containers.sh
fi

# Exécution du script d'installation
log "Exécution du script d'installation"
if [ -f "/opt/monitoring/setup.sh" ]; then
    # Vérifier que le script est exécutable
    sudo chmod +x /opt/monitoring/setup.sh

    # Exécuter le script avec les variables d'environnement
    log "Exécution de setup.sh avec les variables d'environnement..."
    if sudo -E /opt/monitoring/setup.sh > /var/log/setup.log 2>&1; then
        log "Le script setup.sh a été exécuté avec succès"
    else
        log "AVERTISSEMENT: L'exécution du script setup.sh a échoué, consultez /var/log/setup.log pour plus de détails"
        log "Tentative de démarrage manuel des conteneurs..."

        # Vérifier si docker-compose.yml existe
        if [ -f "/opt/monitoring/docker-compose.yml" ]; then
            cd /opt/monitoring
            sudo -E docker-compose up -d || log "AVERTISSEMENT: Échec du démarrage manuel des conteneurs"
        elif [ -f "/opt/monitoring/docker-compose.yml.template" ]; then
            # Copier le template vers docker-compose.yml
            sudo cp /opt/monitoring/docker-compose.yml.template /opt/monitoring/docker-compose.yml
            cd /opt/monitoring
            sudo -E docker-compose up -d || log "AVERTISSEMENT: Échec du démarrage manuel des conteneurs"
        else
            log "AVERTISSEMENT: Aucun fichier docker-compose.yml trouvé"
        fi
    fi
else
    log "AVERTISSEMENT: Le script setup.sh n'existe pas"
    log "Tentative de démarrage manuel des conteneurs..."

    # Vérifier si docker-compose.yml existe
    if [ -f "/opt/monitoring/docker-compose.yml" ]; then
        cd /opt/monitoring
        sudo -E docker-compose up -d || log "AVERTISSEMENT: Échec du démarrage manuel des conteneurs"
    elif [ -f "/opt/monitoring/docker-compose.yml.template" ]; then
        # Copier le template vers docker-compose.yml
        sudo cp /opt/monitoring/docker-compose.yml.template /opt/monitoring/docker-compose.yml
        cd /opt/monitoring
        sudo -E docker-compose up -d || log "AVERTISSEMENT: Échec du démarrage manuel des conteneurs"
    else
        log "AVERTISSEMENT: Aucun fichier docker-compose.yml trouvé"
    fi
fi

# Exécuter le script de correction des conteneurs
log "Exécution du script de correction des conteneurs..."
if [ -f "/opt/monitoring/fix-containers.sh" ]; then
    sudo -E /opt/monitoring/fix-containers.sh > /var/log/fix-containers.log 2>&1
    if [ $? -eq 0 ]; then
        log "Le script fix-containers.sh a été exécuté avec succès"
    else
        log "AVERTISSEMENT: L'exécution du script fix-containers.sh a échoué, consultez /var/log/fix-containers.log pour plus de détails"
    fi
else
    log "AVERTISSEMENT: Le script fix-containers.sh n'existe pas"
fi

# Installer les améliorations de surveillance
log "Installation des améliorations de surveillance..."
if [ "$BUCKET_EXISTS" = true ]; then
    # Télécharger les scripts d'amélioration de surveillance depuis S3
    log "Téléchargement des scripts d'amélioration de surveillance depuis S3..."
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-health-check.sh /opt/monitoring/ || log "Impossible de télécharger container-health-check.sh"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-health-check.service /opt/monitoring/ || log "Impossible de télécharger container-health-check.service"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-health-check.timer /opt/monitoring/ || log "Impossible de télécharger container-health-check.timer"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-tests.sh /opt/monitoring/ || log "Impossible de télécharger container-tests.sh"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-tests.service /opt/monitoring/ || log "Impossible de télécharger container-tests.service"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/container-tests.timer /opt/monitoring/ || log "Impossible de télécharger container-tests.timer"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/loki-config.yml /opt/monitoring/ || log "Impossible de télécharger loki-config.yml"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/promtail-config.yml /opt/monitoring/ || log "Impossible de télécharger promtail-config.yml"
    sudo aws s3 cp s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/setup-monitoring-improvements.sh /opt/monitoring/ || log "Impossible de télécharger setup-monitoring-improvements.sh"
    sudo aws s3 cp --recursive s3://${S3_BUCKET_NAME}/scripts/ec2-monitoring/prometheus-rules/ /opt/monitoring/prometheus-rules/ || log "Impossible de télécharger les règles Prometheus"

    # Rendre les scripts exécutables
    sudo chmod +x /opt/monitoring/container-health-check.sh
    sudo chmod +x /opt/monitoring/container-tests.sh
    sudo chmod +x /opt/monitoring/setup-monitoring-improvements.sh

    # Exécuter le script d'installation des améliorations
    if [ -f "/opt/monitoring/setup-monitoring-improvements.sh" ]; then
        log "Exécution du script d'installation des améliorations..."
        sudo -E /opt/monitoring/setup-monitoring-improvements.sh > /var/log/setup-monitoring-improvements.log 2>&1
        if [ $? -eq 0 ]; then
            log "Le script setup-monitoring-improvements.sh a été exécuté avec succès"
        else
            log "AVERTISSEMENT: L'exécution du script setup-monitoring-improvements.sh a échoué, consultez /var/log/setup-monitoring-improvements.log pour plus de détails"
        fi
    else
        log "AVERTISSEMENT: Le script setup-monitoring-improvements.sh n'existe pas"
    fi
else
    log "AVERTISSEMENT: Le bucket S3 n'est pas accessible, impossible d'installer les améliorations de surveillance"
fi

# Vérifier si les conteneurs sont en cours d'exécution
log "Vérification des conteneurs en cours d'exécution..."
RUNNING_CONTAINERS=$(sudo docker ps --filter "name=prometheus|grafana|sonarqube" --format "{{.Names}}" | wc -l)
log "Nombre de conteneurs en cours d'exécution: $RUNNING_CONTAINERS"

log "Initialisation terminée avec succès"
