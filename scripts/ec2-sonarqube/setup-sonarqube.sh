#!/bin/bash
#==============================================================================
# Nom du script : setup-sonarqube.sh
# Description   : Script d'installation et de configuration pour l'instance EC2 SonarQube.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./setup-sonarqube.sh [options]
#
# Options       :
#   --check     : Vérifie uniquement l'état de l'installation sans rien installer
#   --fix       : Corrige les problèmes détectés
#   --force     : Force la réinstallation même si déjà installé
#   --help      : Affiche l'aide
#
# Exemples      :
#   sudo ./setup-sonarqube.sh
#   sudo ./setup-sonarqube.sh --check
#   sudo ./setup-sonarqube.sh --fix
#   sudo ./setup-sonarqube.sh --force
#==============================================================================
# Dépendances   :
#   - curl      : Pour télécharger des fichiers et récupérer les métadonnées de l'instance
#   - jq        : Pour le traitement JSON
#   - aws-cli   : Pour interagir avec les services AWS
#   - java      : Sera installé par le script (Amazon Corretto 17)
#   - postgresql: Sera installé par le script
#==============================================================================
# Variables d'environnement :
#   - S3_BUCKET_NAME : Nom du bucket S3 contenant les scripts
#   - SONAR_ADMIN_PASSWORD : Mot de passe administrateur SonarQube
#   - DB_USERNAME : Nom d'utilisateur pour la base de données PostgreSQL
#   - DB_PASSWORD : Mot de passe pour la base de données PostgreSQL
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

set -e

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/setup-sonarqube.log|logger -t setup-sonarqube -s 2>/dev/console) 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --check     : Vérifie uniquement l'état de l'installation sans rien installer"
    echo "  --fix       : Corrige les problèmes détectés"
    echo "  --force     : Force la réinstallation même si déjà installé"
    echo "  --help      : Affiche cette aide"
    exit 0
}

# Fonction pour configurer les prérequis système pour SonarQube
configure_system_prerequisites() {
    log "Configuration des prérequis système pour SonarQube"

    # Augmenter la limite de mmap count (nécessaire pour Elasticsearch)
    if grep -q "vm.max_map_count" /etc/sysctl.conf; then
        sed -i 's/vm.max_map_count=.*/vm.max_map_count=262144/' /etc/sysctl.conf
    else
        echo "vm.max_map_count=262144" | tee -a /etc/sysctl.conf
    fi
    sysctl -w vm.max_map_count=262144

    # Augmenter la limite de fichiers ouverts
    if grep -q "fs.file-max" /etc/sysctl.conf; then
        sed -i 's/fs.file-max=.*/fs.file-max=65536/' /etc/sysctl.conf
    else
        echo "fs.file-max=65536" | tee -a /etc/sysctl.conf
    fi
    sysctl -w fs.file-max=65536

    # Configurer les limites de ressources pour l'utilisateur sonarqube
    if ! grep -q "sonarqube.*nofile" /etc/security/limits.conf; then
        echo "sonarqube soft nofile 65536" | tee -a /etc/security/limits.conf
        echo "sonarqube hard nofile 65536" | tee -a /etc/security/limits.conf
        echo "sonarqube soft nproc 4096" | tee -a /etc/security/limits.conf
        echo "sonarqube hard nproc 4096" | tee -a /etc/security/limits.conf
    fi

    log "Prérequis système pour SonarQube configurés avec succès"
    return 0
}

# Fonction pour installer et configurer PostgreSQL
install_postgresql() {
    log "Installation et configuration de PostgreSQL"
    
    # Installer PostgreSQL
    dnf install -y postgresql15 postgresql15-server
    
    # Initialiser PostgreSQL s'il n'est pas déjà initialisé
    if [ ! -f "/var/lib/pgsql/data/postgresql.conf" ]; then
        log "Initialisation de PostgreSQL"
        postgresql-setup --initdb
    else
        log "PostgreSQL est déjà initialisé"
    fi
    
    # Configurer PostgreSQL pour accepter les connexions locales
    log "Configuration de PostgreSQL"
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/g" /var/lib/pgsql/data/postgresql.conf
    sed -i "s/ident/md5/g" /var/lib/pgsql/data/pg_hba.conf
    
    # Démarrer PostgreSQL
    log "Démarrage de PostgreSQL"
    systemctl enable postgresql
    systemctl start postgresql || error_exit "Impossible de démarrer PostgreSQL"
    
    # Créer l'utilisateur et la base de données SonarQube
    log "Création de l'utilisateur et de la base de données SonarQube"
    DB_USERNAME="${DB_USERNAME:-sonar}"
    DB_PASSWORD="${DB_PASSWORD:-sonar}"
    
    # Vérifier si l'utilisateur et la base de données existent déjà
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USERNAME}'" | grep -q 1; then
        log "Création de l'utilisateur ${DB_USERNAME}"
        sudo -u postgres psql -c "CREATE USER ${DB_USERNAME} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';"
    else
        log "L'utilisateur ${DB_USERNAME} existe déjà"
    fi
    
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='sonar'" | grep -q 1; then
        log "Création de la base de données sonar"
        sudo -u postgres psql -c "CREATE DATABASE sonar OWNER ${DB_USERNAME};"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonar TO ${DB_USERNAME};"
    else
        log "La base de données sonar existe déjà"
    fi
    
    log "PostgreSQL installé et configuré avec succès"
    return 0
}

# Fonction pour installer Java
install_java() {
    log "Installation de Java"
    
    # Installer Amazon Corretto 17
    dnf install -y java-17-amazon-corretto-devel
    
    # Vérifier l'installation
    if ! command -v java &> /dev/null; then
        error_exit "L'installation de Java a échoué"
    fi
    
    log "Java installé avec succès: $(java -version 2>&1 | head -n 1)"
    return 0
}

# Fonction pour installer SonarQube
install_sonarqube() {
    log "Installation de SonarQube"
    
    # Créer l'utilisateur sonarqube s'il n'existe pas
    if ! id -u sonarqube &>/dev/null; then
        log "Création de l'utilisateur sonarqube"
        useradd -m -d /opt/sonarqube -s /bin/bash sonarqube
    fi
    
    # Télécharger et installer SonarQube
    SONAR_VERSION="9.9.1.69595"
    
    if [ ! -d "/opt/sonarqube/bin" ]; then
        log "Téléchargement de SonarQube ${SONAR_VERSION}"
        cd /tmp
        wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip || error_exit "Impossible de télécharger SonarQube"
        
        log "Extraction de SonarQube"
        unzip sonarqube-${SONAR_VERSION}.zip -d /opt || error_exit "Impossible de décompresser SonarQube"
        
        # Si le répertoire /opt/sonarqube existe déjà mais est vide
        if [ -d "/opt/sonarqube" ] && [ ! "$(ls -A /opt/sonarqube)" ]; then
            mv /opt/sonarqube-${SONAR_VERSION}/* /opt/sonarqube/
            rmdir /opt/sonarqube-${SONAR_VERSION}
        else
            # Si le répertoire n'existe pas ou n'est pas vide, renommer le répertoire
            mv /opt/sonarqube-${SONAR_VERSION} /opt/sonarqube
        fi
        
        # Nettoyer
        rm -f /tmp/sonarqube-${SONAR_VERSION}.zip
    else
        log "SonarQube est déjà installé"
    fi
    
    # Configurer SonarQube
    log "Configuration de SonarQube"
    DB_USERNAME="${DB_USERNAME:-sonar}"
    DB_PASSWORD="${DB_PASSWORD:-sonar}"
    
    cat > /opt/sonarqube/conf/sonar.properties << EOF
# Base de données
sonar.jdbc.username=${DB_USERNAME}
sonar.jdbc.password=${DB_PASSWORD}
sonar.jdbc.url=jdbc:postgresql://localhost/sonar

# Serveur web
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.context=/

# Elasticsearch
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError

# Compute Engine
sonar.ce.javaOpts=-Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError

# Web Server
sonar.web.javaOpts=-Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError
EOF
    
    # Créer le service systemd pour SonarQube
    log "Création du service systemd pour SonarQube"
    cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Définir les permissions
    log "Définition des permissions"
    chown -R sonarqube:sonarqube /opt/sonarqube
    chmod -R 755 /opt/sonarqube
    
    # Recharger systemd et démarrer SonarQube
    log "Démarrage de SonarQube"
    systemctl daemon-reload
    systemctl enable sonarqube
    systemctl start sonarqube || error_exit "Impossible de démarrer SonarQube"
    
    log "SonarQube installé et configuré avec succès"
    return 0
}

# Fonction pour vérifier l'installation de SonarQube
check_sonarqube() {
    log "Vérification de l'installation de SonarQube"
    
    # Vérifier si le service SonarQube est actif
    if ! systemctl is-active --quiet sonarqube; then
        log "❌ Le service SonarQube n'est pas actif"
        return 1
    fi
    
    # Vérifier si SonarQube répond sur le port 9000
    if ! curl -s http://localhost:9000 > /dev/null; then
        log "❌ SonarQube ne répond pas sur le port 9000"
        return 1
    fi
    
    log "✅ SonarQube est correctement installé et fonctionne"
    return 0
}

# Fonction principale
main() {
    # Traiter les arguments
    CHECK_ONLY=0
    FIX_ISSUES=0
    FORCE_REINSTALL=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                CHECK_ONLY=1
                shift
                ;;
            --fix)
                FIX_ISSUES=1
                shift
                ;;
            --force)
                FORCE_REINSTALL=1
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                log "Option inconnue: $1"
                show_help
                ;;
        esac
    done
    
    # Vérifier les droits sudo
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Ce script doit être exécuté avec sudo ou en tant que root"
    fi
    
    log "Début de l'installation de SonarQube"
    
    # Récupérer les métadonnées de l'instance EC2
    log "Récupération des métadonnées de l'instance EC2"
    EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    EC2_INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
    EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    EC2_INSTANCE_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    log "Instance ID: $EC2_INSTANCE_ID"
    log "Type d'instance: $EC2_INSTANCE_TYPE"
    log "Région: $EC2_INSTANCE_REGION"
    log "Zone de disponibilité: $EC2_INSTANCE_AZ"
    log "IP privée: $EC2_INSTANCE_PRIVATE_IP"
    log "IP publique: $EC2_INSTANCE_PUBLIC_IP"
    
    # Mise à jour du système
    log "Mise à jour du système"
    dnf update -y
    
    # Installation des dépendances nécessaires
    log "Installation des dépendances"
    dnf install -y jq wget unzip
    
    # Vérifier si aws-cli est installé
    log "Installation d'AWS CLI"
    if ! command -v aws &> /dev/null; then
        dnf install -y aws-cli || {
            log "Installation d'AWS CLI via le package aws-cli a échoué, tentative avec awscli..."
            dnf install -y awscli
        }
    else
        log "AWS CLI est déjà installé, version: $(aws --version)"
    fi
    
    # Gérer l'installation de curl séparément pour éviter les conflits avec curl-minimal
    log "Installation de curl"
    if ! command -v curl &> /dev/null; then
        # Si curl n'est pas installé, l'installer avec --allowerasing pour résoudre les conflits
        dnf install -y --allowerasing curl
    else
        log "curl est déjà installé, version: $(curl --version | head -n 1)"
    fi
    
    # Si on est en mode vérification uniquement
    if [ $CHECK_ONLY -eq 1 ]; then
        log "Mode vérification uniquement"
        check_sonarqube
        exit $?
    fi
    
    # Si on est en mode correction
    if [ $FIX_ISSUES -eq 1 ]; then
        log "Mode correction des problèmes"
        if ! check_sonarqube; then
            log "Tentative de correction des problèmes..."
            systemctl restart sonarqube
            sleep 10
            check_sonarqube
        fi
        exit $?
    fi
    
    # Si on est en mode réinstallation forcée
    if [ $FORCE_REINSTALL -eq 1 ]; then
        log "Mode réinstallation forcée"
        log "Arrêt et désactivation de SonarQube"
        systemctl stop sonarqube 2>/dev/null || true
        systemctl disable sonarqube 2>/dev/null || true
        
        log "Suppression des fichiers existants"
        rm -rf /opt/sonarqube
        rm -f /etc/systemd/system/sonarqube.service
        
        log "Réinitialisation de la base de données"
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS sonar;"
        sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USERNAME:-sonar};"
    fi
    
    # Installation et configuration
    configure_system_prerequisites
    install_postgresql
    install_java
    install_sonarqube
    
    # Vérification finale
    if check_sonarqube; then
        log "Installation de SonarQube terminée avec succès"
        log "SonarQube est accessible à l'adresse http://${EC2_INSTANCE_PUBLIC_IP}:9000"
        log "Identifiants par défaut: admin / admin"
        log "Veuillez changer le mot de passe par défaut lors de la première connexion"
    else
        log "L'installation de SonarQube a échoué, veuillez vérifier les logs"
        exit 1
    fi
    
    return 0
}

# Exécuter la fonction principale
main "$@"
