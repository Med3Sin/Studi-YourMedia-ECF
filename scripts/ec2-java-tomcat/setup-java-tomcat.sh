#!/bin/bash
# Script unifié d'installation et de configuration pour l'instance EC2 Java Tomcat
# Ce script combine les fonctionnalités de install_java_tomcat.sh, init-instance-env.sh et fix_permissions.sh
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./setup-java-tomcat.sh
#
# Le script vérifie automatiquement les droits et demandera sudo si nécessaire.

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
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
EC2_INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_INSTANCE_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Vérifier que les variables d'environnement nécessaires sont définies
if [ -z "$TOMCAT_VERSION" ]; then
    log "La variable TOMCAT_VERSION n'est pas définie, utilisation de la valeur par défaut 9.0.104"
    TOMCAT_VERSION="9.0.104"
fi

# Créer les répertoires nécessaires
log "Création des répertoires nécessaires"
mkdir -p /opt/yourmedia/secure || error_exit "Échec de la création du répertoire /opt/yourmedia/secure"
chmod 755 /opt/yourmedia || error_exit "Échec de la modification des permissions de /opt/yourmedia"
chmod 700 /opt/yourmedia/secure || error_exit "Échec de la modification des permissions de /opt/yourmedia/secure"

# Créer le fichier de variables d'environnement
log "Création du fichier de variables d'environnement"
cat > /opt/yourmedia/env.sh << "EOL"
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
cat > /opt/yourmedia/secure/sensitive-env.sh << "EOL"
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

# Mise à jour du système
log "Mise à jour du système"
dnf update -y

# Installation des dépendances nécessaires
log "Installation des dépendances"
dnf install -y aws-cli curl jq wget

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

# Installation de Java
log "Installation de Java (Amazon Corretto 17)"
dnf install -y java-17-amazon-corretto-devel

# Vérifier l'installation de Java
java -version

# Création de l'utilisateur et groupe Tomcat
log "Création de l'utilisateur et groupe Tomcat"
# Vérifier si le groupe tomcat existe déjà
if ! getent group tomcat > /dev/null; then
  groupadd tomcat
  log "Groupe tomcat créé"
else
  log "Le groupe tomcat existe déjà"
fi

# Vérifier si l'utilisateur tomcat existe déjà
if ! id -u tomcat > /dev/null 2>&1; then
  useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
  log "Utilisateur tomcat créé"
else
  log "L'utilisateur tomcat existe déjà"
fi

# Téléchargement et installation de Tomcat
log "Téléchargement et installation de Tomcat $TOMCAT_VERSION"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

cd /tmp
wget $TOMCAT_URL || error_exit "Échec du téléchargement de Tomcat"

# Vérifier que le téléchargement a réussi
if [ ! -f "/tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz" ]; then
  error_exit "Le fichier apache-tomcat-${TOMCAT_VERSION}.tar.gz n'a pas été téléchargé"
fi

# Créer le répertoire Tomcat s'il n'existe pas
mkdir -p /opt/tomcat

# Extraire l'archive
tar xzvf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1 || error_exit "Échec de l'extraction de Tomcat"

# Vérifier que l'extraction a réussi
if [ ! -f "/opt/tomcat/bin/startup.sh" ]; then
  error_exit "L'extraction de Tomcat a échoué, le fichier startup.sh est introuvable"
fi

# Configuration des permissions Tomcat
log "Configuration des permissions Tomcat"
cd /opt/tomcat
chgrp -R tomcat /opt/tomcat
chmod -R g+r conf
chmod g+x conf
chown -R tomcat webapps/ work/ temp/ logs/

# Création du fichier de service Systemd pour Tomcat
log "Création du fichier de service Systemd pour Tomcat"
cat > /etc/systemd/system/tomcat.service << EOF
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
EOF

# Rechargement de Systemd et démarrage de Tomcat
log "Rechargement de Systemd et démarrage de Tomcat"
systemctl daemon-reload
systemctl enable tomcat # Activer le démarrage automatique au boot

# Démarrer Tomcat et vérifier son statut
log "Démarrage de Tomcat"
systemctl start tomcat || true

# Attendre quelques secondes pour que Tomcat démarre
sleep 10

# Création du script de déploiement WAR
log "Création du script de déploiement WAR"
cat > /opt/yourmedia/deploy-war.sh << 'EOF'
#!/bin/bash
# Script pour déployer un fichier WAR dans Tomcat
# Ce script doit être exécuté avec sudo

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  echo "Usage: $0 <chemin_vers_war>"
  exit 1
fi

WAR_PATH=$1
WAR_NAME=$(basename $WAR_PATH)
TARGET_NAME="yourmedia-backend.war"

echo "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  echo "ERREUR: Le fichier $WAR_PATH n'existe pas"
  exit 1
fi

# Copier le fichier WAR dans webapps
cp $WAR_PATH /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si la copie a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec de la copie du fichier WAR dans /opt/tomcat/webapps/"
  exit 1
fi

# Changer le propriétaire
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME

# Vérifier si le changement de propriétaire a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du changement de propriétaire du fichier WAR"
  exit 1
fi

# Redémarrer Tomcat
systemctl restart tomcat

# Vérifier si le redémarrage a réussi
if [ $? -ne 0 ]; then
  echo "ERREUR: Échec du redémarrage de Tomcat"
  exit 1
fi

echo "Déploiement terminé avec succès"
exit 0
EOF

# Rendre le script exécutable
chmod +x /opt/yourmedia/deploy-war.sh

# Créer un lien symbolique pour le script deploy-war.sh
log "Création d'un lien symbolique pour le script deploy-war.sh"
ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
chmod +x /usr/local/bin/deploy-war.sh

# Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war
chmod 440 /etc/sudoers.d/deploy-war

# Création du script de vérification de Tomcat
log "Création du script de vérification de Tomcat"
cat > /opt/yourmedia/check-tomcat.sh << 'EOF'
#!/bin/bash
# Script pour vérifier l'installation de Tomcat

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Vérifier si Java est installé
log "Vérification de l'installation de Java..."
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n 1)
    log "✅ Java est installé: $java_version"
else
    log "❌ Java n'est pas installé."
    exit 1
fi

# Vérifier si Tomcat est installé
log "Vérification de l'installation de Tomcat..."
if [ -d "/opt/tomcat" ]; then
    log "✅ Le répertoire Tomcat existe: /opt/tomcat"
    
    # Vérifier si les fichiers binaires de Tomcat existent
    if [ -f "/opt/tomcat/bin/startup.sh" ] && [ -f "/opt/tomcat/bin/shutdown.sh" ]; then
        log "✅ Les fichiers binaires de Tomcat existent"
    else
        log "❌ Les fichiers binaires de Tomcat n'existent pas"
        exit 1
    fi
    
    # Vérifier si le service Tomcat est configuré
    if systemctl list-unit-files | grep -q tomcat.service; then
        log "✅ Le service Tomcat est configuré"
        
        # Vérifier si le service Tomcat est activé
        if systemctl is-enabled tomcat &> /dev/null; then
            log "✅ Le service Tomcat est activé"
        else
            log "❌ Le service Tomcat n'est pas activé"
            log "Activation du service Tomcat..."
            sudo systemctl enable tomcat
        fi
        
        # Vérifier si le service Tomcat est en cours d'exécution
        if systemctl is-active tomcat &> /dev/null; then
            log "✅ Le service Tomcat est en cours d'exécution"
        else
            log "❌ Le service Tomcat n'est pas en cours d'exécution"
            log "Démarrage du service Tomcat..."
            sudo systemctl start tomcat
        fi
    else
        log "❌ Le service Tomcat n'est pas configuré"
        exit 1
    fi
else
    log "❌ Le répertoire Tomcat n'existe pas: /opt/tomcat"
    exit 1
fi

# Vérifier si le port 8080 est ouvert
log "Vérification du port 8080..."
if netstat -tuln | grep -q ":8080"; then
    log "✅ Le port 8080 est ouvert"
else
    log "❌ Le port 8080 n'est pas ouvert"
    log "Vérification des logs Tomcat..."
    sudo tail -n 50 /opt/tomcat/logs/catalina.out
fi

# Vérifier si le script de déploiement WAR existe
log "Vérification du script de déploiement WAR..."
if [ -f "/opt/yourmedia/deploy-war.sh" ]; then
    log "✅ Le script de déploiement WAR existe: /opt/yourmedia/deploy-war.sh"
else
    log "❌ Le script de déploiement WAR n'existe pas: /opt/yourmedia/deploy-war.sh"
    exit 1
fi

# Vérifier si le lien symbolique vers le script de déploiement WAR existe
log "Vérification du lien symbolique vers le script de déploiement WAR..."
if [ -f "/usr/local/bin/deploy-war.sh" ]; then
    log "✅ Le lien symbolique vers le script de déploiement WAR existe: /usr/local/bin/deploy-war.sh"
else
    log "❌ Le lien symbolique vers le script de déploiement WAR n'existe pas: /usr/local/bin/deploy-war.sh"
    log "Création du lien symbolique..."
    sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
    sudo chmod +x /usr/local/bin/deploy-war.sh
fi

# Afficher un résumé
log "Résumé de la vérification de Tomcat:"
log "- Java est installé: $(java -version 2>&1 | head -n 1)"
log "- Tomcat est installé: $(ls -la /opt/tomcat/bin/startup.sh 2>/dev/null || echo "Non")"
log "- Service Tomcat configuré: $(systemctl is-enabled tomcat 2>/dev/null || echo "Non")"
log "- Service Tomcat en cours d'exécution: $(systemctl is-active tomcat 2>/dev/null || echo "Non")"
log "- Port 8080 ouvert: $(netstat -tuln | grep -q ":8080" && echo "Oui" || echo "Non")"
log "- Script de déploiement WAR: $(ls -la /opt/yourmedia/deploy-war.sh 2>/dev/null || echo "Non")"
log "- Lien symbolique vers le script de déploiement WAR: $(ls -la /usr/local/bin/deploy-war.sh 2>/dev/null || echo "Non")"

log "Vérification terminée"
exit 0
EOF

# Rendre le script exécutable
chmod +x /opt/yourmedia/check-tomcat.sh

# Exécuter le script de vérification de Tomcat
log "Exécution du script de vérification de Tomcat"
/opt/yourmedia/check-tomcat.sh

log "Installation et configuration terminées avec succès"
exit 0
