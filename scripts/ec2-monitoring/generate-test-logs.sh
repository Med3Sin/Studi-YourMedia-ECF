#!/bin/bash
#==============================================================================
# Nom du script : generate-test-logs.sh
# Description   : Script pour générer des logs de test pour Tomcat.
#                 Ce script crée des logs de test avec des timestamps actuels
#                 pour simuler les logs de Tomcat.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 1.0
# Date          : 2025-05-15
#==============================================================================
# Utilisation   : sudo ./generate-test-logs.sh
#==============================================================================
# Dépendances   :
#   - date      : Pour générer des timestamps
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

# Fonction pour afficher les messages d'information
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] $1"
}

# Fonction pour afficher les messages d'erreur et quitter
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR] $1" >&2
    exit 1
}

# Fonction pour afficher les messages de succès
log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [SUCCESS] $1"
}

# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log_error "Ce script doit être exécuté avec sudo ou en tant que root"
fi

# Créer le répertoire pour les logs de test
log_info "Création du répertoire pour les logs de test"
mkdir -p /mnt/ec2-java-tomcat-logs

# Générer des logs de test avec des timestamps actuels
log_info "Génération de logs de test"
cat > /mnt/ec2-java-tomcat-logs/catalina.out << EOF
$(date "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - Server version name:   Apache Tomcat/9.0.104
$(date -d "1 minute ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - Server built:          May 10 2025 08:30:00 UTC
$(date -d "2 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - Server version number: 9.0.104.0
$(date -d "3 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - OS Name:               Linux
$(date -d "4 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - OS Version:            6.1.134-152.225.amzn2023.x86_64
$(date -d "5 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - Architecture:          amd64
$(date -d "6 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - Java Home:             /usr/lib/jvm/java-17-amazon-corretto
$(date -d "7 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - JVM Version:           17.0.9+8-LTS
$(date -d "8 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - JVM Vendor:            Amazon.com Inc.
$(date -d "9 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - CATALINA_BASE:         /opt/tomcat
$(date -d "10 minutes ago" "+%Y-%m-%d %H:%M:%S").000 INFO [main] org.apache.catalina.startup.VersionLoggerListener - CATALINA_HOME:         /opt/tomcat
$(date -d "11 minutes ago" "+%Y-%m-%d %H:%M:%S").000 ERROR [main] org.apache.catalina.startup.Catalina - Error during startup
$(date -d "12 minutes ago" "+%Y-%m-%d %H:%M:%S").000 WARN [main] org.apache.catalina.startup.Catalina - Warning during startup
EOF

# S'assurer que les permissions sont correctes
log_info "Ajustement des permissions"
chmod 644 /mnt/ec2-java-tomcat-logs/catalina.out

# Redémarrer Promtail pour qu'il détecte les nouveaux logs
log_info "Redémarrage de Promtail"
docker restart promtail

log_success "Génération de logs de test terminée avec succès"
exit 0
