#!/bin/bash
# Script simplifié pour déployer un fichier WAR dans Tomcat
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./deploy-war.sh <chemin_vers_war>
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Activer le mode de débogage et la sortie d'erreur en cas d'échec
set -e

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si un argument a été fourni
if [ $# -ne 1 ]; then
  error_exit "Usage: sudo $0 <chemin_vers_war>"
fi

# Vérifier si Tomcat est installé
if [ ! -d "/opt/tomcat" ]; then
  error_exit "Tomcat n'est pas installé dans /opt/tomcat"
fi

# Vérifier si le répertoire webapps existe
if [ ! -d "/opt/tomcat/webapps" ]; then
  error_exit "Le répertoire /opt/tomcat/webapps n'existe pas"
fi

WAR_PATH=$1
TARGET_NAME="yourmedia-backend.war"

log "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  error_exit "Le fichier $WAR_PATH n'existe pas"
fi

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
  error_exit "Ce script doit être exécuté avec sudo. Exemple: sudo $0 $WAR_PATH"
fi

# Vérifier si le service Tomcat existe
if ! systemctl list-unit-files | grep -q tomcat.service; then
  error_exit "Le service Tomcat n'est pas installé"
fi

# Copier le fichier WAR dans webapps
log "Copie du fichier WAR dans /opt/tomcat/webapps/$TARGET_NAME"
cp "$WAR_PATH" /opt/tomcat/webapps/$TARGET_NAME || error_exit "Échec de la copie du fichier WAR"

# Changer le propriétaire
log "Changement du propriétaire du fichier WAR"
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME || error_exit "Échec du changement de propriétaire"

# Redémarrer Tomcat
log "Redémarrage de Tomcat"
systemctl restart tomcat || error_exit "Échec du redémarrage de Tomcat"

# Vérifier que Tomcat est bien démarré
log "Vérification du statut de Tomcat"
sleep 5
if systemctl is-active --quiet tomcat; then
  log "Déploiement terminé avec succès"
  SERVER_IP=$(hostname -I | awk '{print $1}')
  log "L'application sera accessible à l'adresse: http://$SERVER_IP:8080/yourmedia-backend"
else
  error_exit "Le service Tomcat n'a pas démarré correctement"
fi
