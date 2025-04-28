#!/bin/bash
#==============================================================================
# Nom du script : setup-java-tomcat.sh
# Description   : Script unifié d'installation et de configuration pour l'instance EC2 Java Tomcat.
#                 Ce script combine les fonctionnalités de installation, configuration,
#                 vérification et correction des permissions pour Java et Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.0
# Date          : 2025-04-27
#==============================================================================
# Utilisation   : sudo ./setup-java-tomcat.sh [options]
#
# Options       :
#   --check     : Vérifie uniquement l'état de l'installation sans rien installer
#   --fix       : Corrige les problèmes détectés
#   --force     : Force la réinstallation même si déjà installé
#
# Exemples      :
#   sudo ./setup-java-tomcat.sh
#   sudo ./setup-java-tomcat.sh --check
#   sudo ./setup-java-tomcat.sh --fix
#==============================================================================
# Dépendances   :
#   - curl      : Pour télécharger des fichiers et récupérer les métadonnées de l'instance
#   - wget      : Pour télécharger Tomcat
#   - jq        : Pour le traitement JSON
#   - aws-cli   : Pour interagir avec les services AWS
#   - java      : Java 17 (Amazon Corretto) sera installé par le script
#   - netstat   : Pour vérifier les ports ouverts
#==============================================================================
# Variables d'environnement :
#   - S3_BUCKET_NAME : Nom du bucket S3 contenant les scripts
#   - RDS_USERNAME / DB_USERNAME : Nom d'utilisateur RDS
#   - RDS_PASSWORD / DB_PASSWORD : Mot de passe RDS
#   - RDS_ENDPOINT / DB_ENDPOINT : Point de terminaison RDS
#   - TOMCAT_VERSION : Version de Tomcat à installer (par défaut: 9.0.104)
#   - SSH_PUBLIC_KEY : Clé SSH publique à ajouter aux clés autorisées
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Activer le mode de débogage et la sortie d'erreur en cas d'échec
set -e

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/setup-java-tomcat.log|logger -t setup-java-tomcat -s 2>/dev/console) 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Fonction pour installer Java
install_java() {
    log "Installation de Java"
    sudo dnf install -y java-17-amazon-corretto-devel
    if [ $? -ne 0 ]; then
        error_exit "L'installation de Java a échoué"
    fi
    log "Java installé avec succès"
    return 0
}

# Fonction pour installer Tomcat
install_tomcat() {
    log "Installation de Tomcat"

    # Création de l'utilisateur et groupe Tomcat
    log "Création de l'utilisateur et groupe Tomcat"
    sudo groupadd tomcat 2>/dev/null || true
    sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat 2>/dev/null || true

    # Téléchargement et installation de Tomcat
    log "Téléchargement et installation de Tomcat"
    cd /tmp
    sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
    if [ $? -ne 0 ]; then
        error_exit "Le téléchargement de Tomcat a échoué"
    fi

    sudo mkdir -p /opt/tomcat
    sudo tar xzvf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1
    if [ $? -ne 0 ]; then
        error_exit "L'extraction de Tomcat a échoué"
    fi

    # Configuration des permissions
    log "Configuration des permissions"
    sudo chown -R tomcat:tomcat /opt/tomcat
    sudo chmod +x /opt/tomcat/bin/*.sh

    log "Tomcat installé avec succès"
    return 0
}

# Fonction pour configurer le service Tomcat
configure_tomcat_service() {
    log "Création du service Tomcat"
    sudo bash -c 'cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
    if [ $? -ne 0 ]; then
        error_exit "La création du service Tomcat a échoué"
    fi

    # Rechargement des services systemd
    sudo systemctl daemon-reload

    log "Service Tomcat configuré avec succès"
    return 0
}

# Fonction pour démarrer Tomcat
start_tomcat() {
    log "Démarrage de Tomcat"
    sudo systemctl enable tomcat
    sudo systemctl start tomcat

    # Vérifier si Tomcat a démarré correctement
    sleep 5
    if ! systemctl is-active --quiet tomcat; then
        log "Échec du démarrage de Tomcat. Vérification des journaux..."
        journalctl -u tomcat --no-pager -n 50
        return 1
    fi

    log "Tomcat démarré avec succès"
    return 0
}

# Fonction pour créer le script de déploiement WAR
create_deploy_war_script() {
    log "Création du script de déploiement WAR"

    # Créer le répertoire s'il n'existe pas
    sudo mkdir -p /opt/yourmedia

    # Créer le script
    sudo bash -c 'cat > /opt/yourmedia/deploy-war.sh << EOF
#!/bin/bash
# Script pour déployer un fichier WAR dans Tomcat
# Ce script doit être exécuté avec sudo

# Vérifier si un argument a été fourni
if [ \$# -ne 1 ]; then
  echo "Usage: \$0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=\$1
WAR_NAME=\$(basename \$WAR_PATH)
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: \$WAR_PATH vers /opt/tomcat/webapps/\$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "\$WAR_PATH" ]; then
  echo "ERREUR: Le fichier \$WAR_PATH n'\''existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
cp \$WAR_PATH /opt/tomcat/webapps/\$TARGET_NAME

# Vérifier si la copie a réussi
if [ \$? -ne 0 ]; then
  echo "ERREUR: Échec de la copie du fichier WAR dans /opt/tomcat/webapps/"
  exit 1
fi

# Changer le propriétaire
chown tomcat:tomcat /opt/tomcat/webapps/\$TARGET_NAME

# Vérifier si le changement de propriétaire a réussi
if [ \$? -ne 0 ]; then
  echo "ERREUR: Échec du changement de propriétaire du fichier WAR"
  exit 1
fi

# Redémarrer Tomcat
systemctl restart tomcat

# Vérifier si le redémarrage a réussi
if [ \$? -ne 0 ]; then
  echo "ERREUR: Échec du redémarrage de Tomcat"
  exit 1
fi

echo "Déploiement terminé avec succès"
exit 0
EOF'

    # Rendre le script exécutable
    sudo chmod +x /opt/yourmedia/deploy-war.sh

    # Créer un lien symbolique vers le script dans /usr/local/bin
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh

    log "Script de déploiement WAR créé avec succès"
    return 0
}

# Fonction pour vérifier l'état de Tomcat
check_tomcat() {
    local fix_issues=$1
    local status=0

    log "Vérification de l'installation de Java..."
    if command -v java &> /dev/null; then
        java_version=$(java -version 2>&1 | head -n 1)
        log "✅ Java est installé: $java_version"
    else
        log "❌ Java n'est pas installé."
        if [ "$fix_issues" = "true" ]; then
            log "Installation de Java..."
            sudo dnf install -y java-17-amazon-corretto-devel
            if [ $? -eq 0 ]; then
                log "✅ Java a été installé avec succès."
            else
                log "❌ L'installation de Java a échoué."
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification de l'installation de Tomcat..."
    if [ -d "/opt/tomcat" ]; then
        log "✅ Le répertoire Tomcat existe: /opt/tomcat"

        # Vérifier si les fichiers binaires de Tomcat existent
        if [ -f "/opt/tomcat/bin/startup.sh" ] && [ -f "/opt/tomcat/bin/shutdown.sh" ]; then
            log "✅ Les fichiers binaires de Tomcat existent."
        else
            log "❌ Les fichiers binaires de Tomcat n'existent pas."
            if [ "$fix_issues" = "true" ]; then
                log "Réinstallation de Tomcat..."
                install_tomcat
                if [ $? -eq 0 ]; then
                    log "✅ Tomcat a été réinstallé avec succès."
                else
                    log "❌ La réinstallation de Tomcat a échoué."
                    return 1
                fi
            else
                status=1
            fi
        fi
    else
        log "❌ Le répertoire Tomcat n'existe pas: /opt/tomcat"
        if [ "$fix_issues" = "true" ]; then
            log "Installation de Tomcat..."
            install_tomcat
            if [ $? -eq 0 ]; then
                log "✅ Tomcat a été installé avec succès."
            else
                log "❌ L'installation de Tomcat a échoué."
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification de la configuration du service Tomcat..."
    if [ -f "/etc/systemd/system/tomcat.service" ]; then
        log "✅ Le service Tomcat est configuré."
    else
        log "❌ Le service Tomcat n'est pas configuré."
        if [ "$fix_issues" = "true" ]; then
            log "Configuration du service Tomcat..."
            configure_tomcat_service
            if [ $? -eq 0 ]; then
                log "✅ Le service Tomcat a été configuré avec succès."
            else
                log "❌ La configuration du service Tomcat a échoué."
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification de l'activation du service Tomcat..."
    if systemctl is-enabled --quiet tomcat; then
        log "✅ Le service Tomcat est activé."
    else
        log "❌ Le service Tomcat n'est pas activé."
        if [ "$fix_issues" = "true" ]; then
            log "Activation du service Tomcat..."
            sudo systemctl enable tomcat
            log "✅ Le service Tomcat a été activé."
        else
            status=1
        fi
    fi

    log "Vérification de l'état du service Tomcat..."
    if systemctl is-active --quiet tomcat; then
        log "✅ Le service Tomcat est en cours d'exécution."
    else
        log "❌ Le service Tomcat n'est pas en cours d'exécution."
        if [ "$fix_issues" = "true" ]; then
            log "Démarrage du service Tomcat..."
            sudo systemctl start tomcat

            # Attendre quelques secondes pour que Tomcat démarre
            sleep 10

            # Vérifier à nouveau l'état du service
            if systemctl is-active --quiet tomcat; then
                log "✅ Le service Tomcat a été démarré avec succès."
            else
                log "❌ Le démarrage du service Tomcat a échoué."
                log "Vérification des journaux Tomcat..."
                journalctl -u tomcat --no-pager -n 50
                return 1
            fi
        else
            status=1
        fi
    fi

    log "Vérification du port 8080..."
    # S'assurer que netstat est installé
    if ! command -v netstat &> /dev/null; then
        log "Installation de net-tools pour netstat..."
        dnf install -y net-tools
    fi
    if netstat -tuln | grep -q ":8080"; then
        log "✅ Le port 8080 est ouvert."
    else
        log "❌ Le port 8080 n'est pas ouvert."
        if [ "$fix_issues" = "true" ]; then
            log "Redémarrage du service Tomcat..."
            sudo systemctl restart tomcat
            sleep 10
            if netstat -tuln | grep -q ":8080"; then
                log "✅ Le port 8080 est maintenant ouvert."
            else
                log "❌ Le port 8080 n'est toujours pas ouvert."
                log "Vérification des journaux Tomcat..."
                journalctl -u tomcat --no-pager -n 50
                return 1
            fi
        else
            status=1
        fi
    fi

    # Afficher un résumé
    log "Résumé de la vérification de Tomcat:"
    log "- Java est installé: $(java -version 2>&1 | head -n 1)"
    log "- Tomcat est installé: $(ls -la /opt/tomcat/bin/startup.sh 2>/dev/null || echo "Non")"
    log "- Service Tomcat configuré: $(systemctl is-enabled tomcat 2>/dev/null || echo "Non")"
    log "- Service Tomcat en cours d'exécution: $(systemctl is-active tomcat 2>/dev/null || echo "Non")"
    log "- Port 8080 ouvert: $(netstat -tuln | grep -q ":8080" && echo "Oui" || echo "Non")"
    log "- Script de déploiement WAR: $(ls -la /opt/yourmedia/deploy-war.sh 2>/dev/null || echo "Non")"

    return $status
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script nécessite des privilèges sudo."
    if sudo -n true 2>/dev/null; then
        log "Privilèges sudo disponibles sans mot de passe."
    else
        log "Tentative d'obtention des privilèges sudo..."
        if ! sudo -v; then
            error_exit "Impossible d'obtenir les privilèges sudo. Veuillez exécuter ce script avec sudo ou en tant que root."
        fi
        log "Privilèges sudo obtenus avec succès."
    fi
fi

# Vérification du système d'exploitation
log "Vérification du système d'exploitation..."
if [ ! -f "/etc/os-release" ] || ! grep -q "Amazon Linux" /etc/os-release; then
    error_exit "Ce script est conçu pour Amazon Linux. Veuillez l'adapter pour votre système d'exploitation."
fi

# Charger les variables d'environnement si elles existent
if [ -f "/opt/yourmedia/env.sh" ]; then
    log "Chargement des variables d'environnement depuis /opt/yourmedia/env.sh"
    source /opt/yourmedia/env.sh
fi

# Charger les variables sensibles si elles existent
if [ -f "/opt/yourmedia/secure/sensitive-env.sh" ]; then
    log "Chargement des variables sensibles depuis /opt/yourmedia/secure/sensitive-env.sh"
    source /opt/yourmedia/secure/sensitive-env.sh
fi

# Définir les variables d'environnement
log "Configuration des variables d'environnement"
# Variables EC2 - Standardisation sur EC2_*
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Variables Tomcat - Standardisation sur TOMCAT_*
if [ -z "$TOMCAT_VERSION" ]; then
    log "La variable TOMCAT_VERSION n'est pas définie, utilisation de la valeur par défaut 9.0.104"
    TOMCAT_VERSION="9.0.104"
fi

# Variables S3 - Standardisation sur S3_*
if [ -z "$S3_BUCKET_NAME" ]; then
    log "La variable S3_BUCKET_NAME n'est pas définie, utilisation de la valeur par défaut yourmedia-ecf-studi"
    S3_BUCKET_NAME="yourmedia-ecf-studi"
fi

# Variables RDS - Standardisation sur RDS_*
if [ -z "$RDS_USERNAME" ] && [ -n "$DB_USERNAME" ]; then
    RDS_USERNAME="$DB_USERNAME"
elif [ -z "$RDS_USERNAME" ]; then
    RDS_USERNAME="yourmedia"
    log "La variable RDS_USERNAME n'est pas définie, utilisation de la valeur par défaut $RDS_USERNAME"
fi

if [ -z "$RDS_PASSWORD" ] && [ -n "$DB_PASSWORD" ]; then
    RDS_PASSWORD="$DB_PASSWORD"
elif [ -z "$RDS_PASSWORD" ]; then
    RDS_PASSWORD="password"
    log "La variable RDS_PASSWORD n'est pas définie, utilisation de la valeur par défaut (non sécurisée)"
fi

if [ -z "$RDS_ENDPOINT" ] && [ -n "$DB_ENDPOINT" ]; then
    RDS_ENDPOINT="$DB_ENDPOINT"
elif [ -z "$RDS_ENDPOINT" ]; then
    RDS_ENDPOINT="localhost:3306"
    log "La variable RDS_ENDPOINT n'est pas définie, utilisation de la valeur par défaut $RDS_ENDPOINT"
fi

# Variables de compatibilité
DB_USERNAME="$RDS_USERNAME"
DB_PASSWORD="$RDS_PASSWORD"
DB_ENDPOINT="$RDS_ENDPOINT"

# Créer les répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/yourmedia/secure || error_exit "Échec de la création du répertoire /opt/yourmedia/secure"
chmod 755 /opt/yourmedia || error_exit "Échec de la modification des permissions de /opt/yourmedia"
chmod 700 /opt/yourmedia/secure || error_exit "Échec de la modification des permissions de /opt/yourmedia/secure"

# Créer le fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
cat > /opt/yourmedia/env.sh << EOL
#!/bin/bash
# Variables d'environnement pour l'application Java Tomcat
# Généré automatiquement par setup-java-tomcat.sh
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$EC2_INSTANCE_PUBLIC_IP"
export EC2_INSTANCE_ID="$EC2_INSTANCE_ID"
export EC2_INSTANCE_REGION="$EC2_INSTANCE_REGION"

# Variables S3
export S3_BUCKET_NAME="${S3_BUCKET_NAME:-yourmedia-ecf-studi}"

# Variables RDS
export RDS_USERNAME="${RDS_USERNAME:-yourmedia}"
export RDS_ENDPOINT="${RDS_ENDPOINT:-localhost:3306}"

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_ENDPOINT="$RDS_ENDPOINT"

# Variable Tomcat
export TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.104}"

# Charger les variables sensibles
source /opt/yourmedia/secure/sensitive-env.sh 2>/dev/null || true
EOL

# Créer le fichier de variables sensibles
log "Création du fichier de variables sensibles"
cat > /opt/yourmedia/secure/sensitive-env.sh << EOL
#!/bin/bash
# Variables sensibles pour l'application Java Tomcat
# Généré automatiquement par setup-java-tomcat.sh
# Date de génération: $(date)

# Variables RDS
export RDS_PASSWORD="${RDS_PASSWORD:-password}"

# Variables de compatibilité
export DB_PASSWORD="$RDS_PASSWORD"
EOL

# Définir les permissions
chmod 755 /opt/yourmedia/env.sh
chmod 600 /opt/yourmedia/secure/sensitive-env.sh
chown -R ec2-user:ec2-user /opt/yourmedia

# Fonction pour installer et configurer tout
setup_java_tomcat() {
    # Mise à jour du système
    log "Mise à jour du système"
    dnf update -y

    # Installation des dépendances nécessaires
    log "Installation des dépendances"
    # Installer jq et wget
    dnf install -y jq wget

    # Vérifier si aws-cli est installé
    if ! command -v aws &> /dev/null; then
        log "Installation d'AWS CLI..."
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

    # Configuration des clés SSH
    log "Configuration des clés SSH"
    mkdir -p /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh

    # Récupérer la clé publique depuis les métadonnées de l'instance (si disponible)
    PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
    if [ ! -z "$PUBLIC_KEY" ]; then
        echo "$PUBLIC_KEY" | tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
        log "Clé SSH publique AWS installée avec succès"
    fi

    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh

    # Créer les répertoires nécessaires
    log "Création des répertoires nécessaires"
    mkdir -p /opt/yourmedia/secure || error_exit "Échec de la création du répertoire /opt/yourmedia/secure"
    chmod 755 /opt/yourmedia || error_exit "Échec de la modification des permissions de /opt/yourmedia"
    chmod 700 /opt/yourmedia/secure || error_exit "Échec de la modification des permissions de /opt/yourmedia/secure"

    # Créer le fichier de variables d'environnement
    log "Création du fichier de variables d'environnement"
    cat > /opt/yourmedia/env.sh << EOL
#!/bin/bash
# Variables d'environnement pour l'application Java Tomcat
# Généré automatiquement par setup-java-tomcat.sh
# Date de génération: $(date)

# Variables EC2
export EC2_INSTANCE_PRIVATE_IP="$EC2_INSTANCE_PRIVATE_IP"
export EC2_INSTANCE_PUBLIC_IP="$EC2_INSTANCE_PUBLIC_IP"
export EC2_INSTANCE_ID="$EC2_INSTANCE_ID"
export EC2_INSTANCE_REGION="$EC2_INSTANCE_REGION"

# Variables S3
export S3_BUCKET_NAME="${S3_BUCKET_NAME:-yourmedia-ecf-studi}"

# Variables RDS
export RDS_USERNAME="${RDS_USERNAME:-yourmedia}"
export RDS_ENDPOINT="${RDS_ENDPOINT:-localhost:3306}"

# Variables de compatibilité
export DB_USERNAME="$RDS_USERNAME"
export DB_ENDPOINT="$RDS_ENDPOINT"

# Variable Tomcat
export TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.104}"

# Charger les variables sensibles
source /opt/yourmedia/secure/sensitive-env.sh 2>/dev/null || true
EOL

    # Créer le fichier de variables sensibles
    log "Création du fichier de variables sensibles"
    cat > /opt/yourmedia/secure/sensitive-env.sh << EOL
#!/bin/bash
# Variables sensibles pour l'application Java Tomcat
# Généré automatiquement par setup-java-tomcat.sh
# Date de génération: $(date)

# Variables RDS
export RDS_PASSWORD="${RDS_PASSWORD:-password}"

# Variables de compatibilité
export DB_PASSWORD="$RDS_PASSWORD"
EOL

    # Définir les permissions
    chmod 755 /opt/yourmedia/env.sh
    chmod 600 /opt/yourmedia/secure/sensitive-env.sh
    chown -R ec2-user:ec2-user /opt/yourmedia

    # Installation de Java
    install_java

    # Installation de Tomcat
    install_tomcat

    # Configuration du service Tomcat
    configure_tomcat_service

    # Démarrage de Tomcat
    start_tomcat

    # Création du script de déploiement WAR
    create_deploy_war_script

    # Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
    echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war
    chmod 440 /etc/sudoers.d/deploy-war

    return 0
}

# Traitement des arguments de ligne de commande
MODE="install"
FORCE=false

# Analyser les arguments
for arg in "$@"; do
    case $arg in
        --check)
            MODE="check"
            shift
            ;;
        --fix)
            MODE="fix"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--check] [--fix] [--force]"
            echo ""
            echo "Options:"
            echo "  --check    Vérifie uniquement l'état de l'installation sans rien installer"
            echo "  --fix      Corrige les problèmes détectés"
            echo "  --force    Force la réinstallation même si déjà installé"
            echo "  --help     Affiche cette aide"
            exit 0
            ;;
        *)
            # Argument inconnu
            log "Argument inconnu: $arg"
            echo "Utilisez --help pour afficher l'aide"
            exit 1
            ;;
    esac
done

# Exécuter le mode approprié
case $MODE in
    check)
        log "Mode vérification uniquement"
        check_tomcat false
        if [ $? -eq 0 ]; then
            log "✅ Vérification terminée avec succès. Tout est correctement configuré."
            exit 0
        else
            log "❌ Vérification terminée avec des erreurs. Utilisez --fix pour corriger les problèmes."
            exit 1
        fi
        ;;
    fix)
        log "Mode correction des problèmes"
        check_tomcat true
        if [ $? -eq 0 ]; then
            log "✅ Correction terminée avec succès. Tout est correctement configuré."
            exit 0
        else
            log "❌ Correction terminée avec des erreurs. Veuillez vérifier les journaux."
            exit 1
        fi
        ;;
    install)
        # Si Tomcat est déjà installé et que --force n'est pas spécifié, vérifier seulement
        if [ -d "/opt/tomcat" ] && [ -f "/etc/systemd/system/tomcat.service" ] && [ "$FORCE" = "false" ]; then
            log "Tomcat semble déjà installé. Vérification de l'installation..."
            check_tomcat true
            if [ $? -eq 0 ]; then
                log "✅ Installation et configuration terminées avec succès."
                exit 0
            else
                log "❌ Des problèmes ont été détectés et n'ont pas pu être corrigés automatiquement."
                exit 1
            fi
        else
            # Installation complète
            log "Mode installation complète"
            if [ "$FORCE" = "true" ]; then
                log "Mode force activé. Réinstallation complète."
                # Arrêter et désactiver Tomcat s'il est déjà installé
                if [ -f "/etc/systemd/system/tomcat.service" ]; then
                    log "Arrêt et désactivation de Tomcat..."
                    systemctl stop tomcat
                    systemctl disable tomcat
                fi
                # Supprimer les répertoires existants
                if [ -d "/opt/tomcat" ]; then
                    log "Suppression du répertoire /opt/tomcat..."
                    rm -rf /opt/tomcat
                fi
            fi

            # Exécuter l'installation complète
            setup_java_tomcat

            # Vérifier l'installation
            check_tomcat true
            if [ $? -eq 0 ]; then
                log "✅ Installation et configuration terminées avec succès."
                exit 0
            else
                log "❌ L'installation a échoué. Veuillez vérifier les journaux."
                exit 1
            fi
        fi
        ;;
esac

log "Installation et configuration terminées avec succès"
exit 0
