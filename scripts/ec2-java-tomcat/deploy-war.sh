#!/bin/bash
# Script amélioré pour déployer un fichier WAR dans Tomcat
#
# EXIGENCES EN MATIÈRE DE DROITS :
# Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
# Exemple d'utilisation : sudo ./deploy-war.sh <chemin_vers_war>
#
# Le script vérifie automatiquement les droits et affichera une erreur si nécessaire.

# Activer le mode de débogage et la sortie d'erreur en cas d'échec
set -e

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/deploy-war.log) 2>&1

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

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
  error_exit "Ce script doit être exécuté avec sudo. Exemple: sudo $0 $WAR_PATH"
fi

WAR_PATH=$1
TARGET_NAME="yourmedia-backend.war"

log "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  error_exit "Le fichier $WAR_PATH n'existe pas"
fi

# Vérifier si Tomcat est installé
if [ ! -d "/opt/tomcat" ]; then
  log "Le répertoire /opt/tomcat n'existe pas, création..."
  mkdir -p /opt/tomcat
  chown -R tomcat:tomcat /opt/tomcat
fi

# Vérifier si le répertoire webapps existe
if [ ! -d "/opt/tomcat/webapps" ]; then
  log "Le répertoire /opt/tomcat/webapps n'existe pas, création..."
  mkdir -p /opt/tomcat/webapps
  chown tomcat:tomcat /opt/tomcat/webapps
fi

# Vérifier si le service Tomcat existe
if ! systemctl list-unit-files | grep -q tomcat.service; then
  log "Le service Tomcat n'est pas installé, vérification de l'installation..."

  # Vérifier si le script d'installation existe
  if [ -f "/opt/yourmedia/install_java_tomcat.sh" ]; then
    log "Exécution du script d'installation de Java et Tomcat..."
    chmod +x /opt/yourmedia/install_java_tomcat.sh
    /opt/yourmedia/install_java_tomcat.sh
  else
    error_exit "Le service Tomcat n'est pas installé et le script d'installation n'existe pas"
  fi
fi

# Arrêter Tomcat avant le déploiement
log "Arrêt de Tomcat..."
systemctl stop tomcat || log "AVERTISSEMENT: Échec de l'arrêt de Tomcat, poursuite du déploiement..."

# Attendre que Tomcat s'arrête complètement
sleep 5

# Supprimer l'ancienne application déployée si elle existe
if [ -d "/opt/tomcat/webapps/yourmedia-backend" ]; then
  log "Suppression de l'ancienne application déployée..."
  rm -rf /opt/tomcat/webapps/yourmedia-backend
fi

# Copier le fichier WAR dans webapps
log "Copie du fichier WAR dans /opt/tomcat/webapps/$TARGET_NAME"
cp "$WAR_PATH" /opt/tomcat/webapps/$TARGET_NAME || error_exit "Échec de la copie du fichier WAR"

# Changer le propriétaire
log "Changement du propriétaire du fichier WAR"
chown tomcat:tomcat /opt/tomcat/webapps/$TARGET_NAME || error_exit "Échec du changement de propriétaire"

# Démarrer Tomcat
log "Démarrage de Tomcat"
systemctl start tomcat || error_exit "Échec du démarrage de Tomcat"

# Vérifier que Tomcat est bien démarré
log "Vérification du statut de Tomcat"
sleep 10
if systemctl is-active --quiet tomcat; then
  log "Déploiement terminé avec succès"
  SERVER_IP=$(hostname -I | awk '{print $1}')
  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")

  if [ -n "$PUBLIC_IP" ]; then
    log "L'application sera accessible à l'adresse: http://$PUBLIC_IP:8080/yourmedia-backend"
  else
    log "L'application sera accessible à l'adresse: http://$SERVER_IP:8080/yourmedia-backend"
  fi

  # Vérifier si l'application se déploie correctement
  log "Vérification du déploiement de l'application..."
  TIMEOUT=60
  START_TIME=$(date +%s)

  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
      log "AVERTISSEMENT: Délai d'attente dépassé pour le déploiement de l'application"
      break
    fi

    if [ -d "/opt/tomcat/webapps/yourmedia-backend" ]; then
      log "Application déployée avec succès"
      break
    fi

    log "En attente du déploiement de l'application... ($ELAPSED_TIME secondes écoulées)"
    sleep 5
  done

  exit 0
else
  error_exit "Le service Tomcat n'a pas démarré correctement. Vérifiez les logs avec 'journalctl -u tomcat'"
fi
