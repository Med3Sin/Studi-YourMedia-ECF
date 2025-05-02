#!/bin/bash
#==============================================================================
# Nom du script : deploy-war.sh
# Description   : Script simplifié pour déployer un fichier WAR dans Tomcat.
#                 Ce script gère le déploiement, la vérification et le redémarrage
#                 de Tomcat pour assurer que l'application est correctement déployée.
# Auteur        : Med3Sin <0medsin0@gmail.com>
# Version       : 2.1
# Date          : 2023-11-15
#==============================================================================
# Utilisation   : sudo ./deploy-war.sh <chemin_vers_war> [options]
#
# Options       :
#   --context=NOM  : Nom du contexte de l'application (par défaut: yourmedia-backend)
#   --no-restart   : Ne pas redémarrer Tomcat après le déploiement
#   --timeout=SEC  : Délai d'attente en secondes pour le déploiement (par défaut: 60)
#
# Exemples      :
#   sudo ./deploy-war.sh /chemin/vers/application.war
#   sudo ./deploy-war.sh /chemin/vers/application.war --context=monapp
#   sudo ./deploy-war.sh /chemin/vers/application.war --no-restart
#==============================================================================
# Dépendances   :
#   - systemctl   : Pour gérer le service Tomcat
#   - wget        : Pour récupérer l'adresse IP publique
#==============================================================================
# Droits requis : Ce script doit être exécuté avec des privilèges sudo ou en tant que root.
#==============================================================================

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

# Variables par défaut
CONTEXT_NAME="yourmedia-backend"
RESTART_TOMCAT=true
TIMEOUT=60

# Traitement des arguments
if [ $# -lt 1 ]; then
  error_exit "Usage: sudo $0 <chemin_vers_war> [options]"
fi

WAR_PATH=$1
shift

# Traiter les options supplémentaires
while [ $# -gt 0 ]; do
  case "$1" in
    --context=*)
      CONTEXT_NAME="${1#*=}"
      shift
      ;;
    --no-restart)
      RESTART_TOMCAT=false
      shift
      ;;
    --timeout=*)
      TIMEOUT="${1#*=}"
      if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
        error_exit "Le délai d'attente doit être un nombre entier"
      fi
      shift
      ;;
    *)
      error_exit "Option inconnue: $1"
      ;;
  esac
done

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
  error_exit "Ce script doit être exécuté avec sudo. Exemple: sudo $0 $WAR_PATH"
fi

TARGET_NAME="${CONTEXT_NAME}.war"

log "Déploiement du fichier WAR: $WAR_PATH vers /opt/tomcat/webapps/$TARGET_NAME"
log "Contexte: $CONTEXT_NAME"
log "Redémarrage de Tomcat: $([ "$RESTART_TOMCAT" = true ] && echo "Oui" || echo "Non")"
log "Délai d'attente: $TIMEOUT secondes"

# Vérifier si le fichier existe
if [ ! -f "$WAR_PATH" ]; then
  error_exit "Le fichier $WAR_PATH n'existe pas"
fi

# Fonction pour vérifier l'installation de Tomcat
check_tomcat_installation() {
  log "Vérification de l'installation de Tomcat..."

  # Vérifier si Tomcat est installé
  if [ ! -d "/opt/tomcat" ]; then
    log "Le répertoire /opt/tomcat n'existe pas, création..."
    sudo mkdir -p /opt/tomcat
    sudo chown -R tomcat:tomcat /opt/tomcat
  fi

  # Vérifier si le répertoire webapps existe
  if [ ! -d "/opt/tomcat/webapps" ]; then
    log "Le répertoire /opt/tomcat/webapps n'existe pas, création..."
    sudo mkdir -p /opt/tomcat/webapps
    sudo chown tomcat:tomcat /opt/tomcat/webapps
  fi

  # Vérifier si le service Tomcat existe
  if ! sudo systemctl list-unit-files | grep -q tomcat.service; then
    log "Le service Tomcat n'est pas installé, vérification de l'installation..."

    # Vérifier si le script d'installation existe
    if [ -f "/opt/yourmedia/setup-java-tomcat.sh" ]; then
      log "Exécution du script d'installation de Java et Tomcat..."
      sudo chmod +x /opt/yourmedia/setup-java-tomcat.sh
      sudo /opt/yourmedia/setup-java-tomcat.sh
    else
      error_exit "Le service Tomcat n'est pas installé et le script d'installation n'existe pas"
    fi
  fi

  # Vérifier si le service Tomcat est actif
  if ! sudo systemctl is-active --quiet tomcat; then
    log "Le service Tomcat n'est pas actif, démarrage..."
    sudo systemctl start tomcat || error_exit "Échec du démarrage de Tomcat"
    sleep 5
  fi

  log "Vérification de l'installation de Tomcat terminée"
}

# Fonction pour déployer le fichier WAR
deploy_war() {
  local war_path=$1
  local target_name=$2
  local context_name=$3
  local restart=$4

  log "Déploiement du fichier WAR: $war_path vers /opt/tomcat/webapps/$target_name"

  # Arrêter Tomcat avant le déploiement si nécessaire
  if [ "$restart" = true ]; then
    log "Arrêt de Tomcat..."
    sudo systemctl stop tomcat || log "AVERTISSEMENT: Échec de l'arrêt de Tomcat, poursuite du déploiement..."

    # Attendre que Tomcat s'arrête complètement
    sleep 5
  fi

  # Supprimer l'ancienne application déployée si elle existe
  if [ -d "/opt/tomcat/webapps/$context_name" ]; then
    log "Suppression de l'ancienne application déployée..."
    sudo rm -rf "/opt/tomcat/webapps/$context_name"
  fi

  # Supprimer l'ancien fichier WAR s'il existe
  if [ -f "/opt/tomcat/webapps/$target_name" ]; then
    log "Suppression de l'ancien fichier WAR..."
    sudo rm -f "/opt/tomcat/webapps/$target_name"
  fi

  # Copier le fichier WAR dans webapps
  log "Copie du fichier WAR dans /opt/tomcat/webapps/$target_name"
  sudo cp "$war_path" "/opt/tomcat/webapps/$target_name" || error_exit "Échec de la copie du fichier WAR"

  # Changer le propriétaire
  log "Changement du propriétaire du fichier WAR"
  sudo chown tomcat:tomcat "/opt/tomcat/webapps/$target_name" || error_exit "Échec du changement de propriétaire"

  # Démarrer Tomcat si nécessaire
  if [ "$restart" = true ]; then
    log "Démarrage de Tomcat"
    sudo systemctl start tomcat || error_exit "Échec du démarrage de Tomcat"
  fi

  log "Déploiement du fichier WAR terminé"
}

# Vérifier l'installation de Tomcat
check_tomcat_installation

# Déployer le fichier WAR
deploy_war "$WAR_PATH" "$TARGET_NAME" "$CONTEXT_NAME" "$RESTART_TOMCAT"

# Fonction pour vérifier le déploiement de l'application
check_deployment() {
  local context_name=$1
  local timeout=$2

  log "Vérification du déploiement de l'application..."

  # Vérifier que Tomcat est bien démarré
  if ! sudo systemctl is-active --quiet tomcat; then
    if [ "$RESTART_TOMCAT" = true ]; then
      error_exit "Le service Tomcat n'a pas démarré correctement. Vérifiez les logs avec 'journalctl -u tomcat'"
    else
      log "AVERTISSEMENT: Le service Tomcat n'est pas actif. L'application ne sera pas déployée immédiatement."
      log "Démarrez Tomcat manuellement avec 'sudo systemctl start tomcat' pour terminer le déploiement."
      return 1
    fi
  fi

  # Vérifier si l'application se déploie correctement
  local start_time=$(date +%s)

  while true; do
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))

    if [ $elapsed_time -gt $timeout ]; then
      log "AVERTISSEMENT: Délai d'attente dépassé pour le déploiement de l'application"
      return 1
    fi

    if [ -d "/opt/tomcat/webapps/$context_name" ]; then
      log "Application déployée avec succès"
      return 0
    fi

    log "En attente du déploiement de l'application... ($elapsed_time secondes écoulées)"
    sleep 5
  done
}

# Fonction pour afficher les informations d'accès
show_access_info() {
  local context_name=$1

  log "Récupération des informations d'accès..."

  # Récupérer les adresses IP
  local server_ip=$(hostname -I | awk '{print $1}')
  local public_ip=$(sudo wget -q -O - --timeout=5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")

  log "Déploiement terminé avec succès"

  if [ -n "$public_ip" ]; then
    log "L'application sera accessible à l'adresse: http://$public_ip:8080/$context_name"
  else
    log "L'application sera accessible à l'adresse: http://$server_ip:8080/$context_name"
  fi

  # Vérifier si Tomcat est configuré avec un port différent
  if [ -f "/opt/tomcat/conf/server.xml" ]; then
    local custom_port=$(grep -oP '(?<=port=")([0-9]+)(?=")' /opt/tomcat/conf/server.xml | grep -v "8005\|8009\|8443" | head -1)
    if [ -n "$custom_port" ] && [ "$custom_port" != "8080" ]; then
      log "Note: Tomcat semble être configuré sur le port $custom_port"
      if [ -n "$public_ip" ]; then
        log "L'application sera accessible à l'adresse: http://$public_ip:$custom_port/$context_name"
      else
        log "L'application sera accessible à l'adresse: http://$server_ip:$custom_port/$context_name"
      fi
    fi
  fi
}

# Vérifier le déploiement de l'application
if check_deployment "$CONTEXT_NAME" "$TIMEOUT"; then
  # Afficher les informations d'accès
  show_access_info "$CONTEXT_NAME"
  exit 0
else
  log "Le déploiement de l'application n'a pas pu être vérifié dans le délai imparti"
  log "Vérifiez les logs de Tomcat avec 'sudo journalctl -u tomcat' pour plus d'informations"
  exit 1
fi
