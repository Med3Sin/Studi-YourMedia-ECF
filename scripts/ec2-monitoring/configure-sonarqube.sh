#!/bin/bash

# Script simplifié pour configurer SonarQube sur l'instance EC2 de monitoring

# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo"
  echo "Exemple: sudo $0"
  exit 1
fi

# Définir les variables
SONAR_HOME="/opt/sonarqube"
SONAR_PORT=9000
SONAR_ADMIN_USER="admin"
SONAR_ADMIN_PASSWORD="admin"
SONAR_NEW_PASSWORD=${1:-"YourMedia2024!"}

# Vérifier si SonarQube est installé
if [ ! -d "$SONAR_HOME" ]; then
  echo "SonarQube n'est pas installé dans $SONAR_HOME"
  echo "Veuillez installer SonarQube d'abord"
  exit 1
fi

# Démarrer SonarQube s'il n'est pas en cours d'exécution
if ! pgrep -f "org.sonar.server.app.WebServer" > /dev/null; then
  echo "Démarrage de SonarQube..."
  systemctl start sonarqube || su sonar -c "$SONAR_HOME/bin/linux-x86-64/sonar.sh start"
  echo "Attente du démarrage de SonarQube..."
  sleep 30
fi

# Installer curl et jq si nécessaire
if ! command -v curl &> /dev/null; then
  echo "Installation de curl..."
  yum install -y curl || apt-get install -y curl
fi

# Fonction simplifiée pour appeler l'API SonarQube
call_api() {
  local method=$1
  local endpoint=$2
  local data=$3
  local auth="$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD"

  if [ -n "$data" ]; then
    curl -s -X "$method" -u "$auth" -d "$data" "http://localhost:$SONAR_PORT/api/$endpoint"
  else
    curl -s -X "$method" -u "$auth" "http://localhost:$SONAR_PORT/api/$endpoint"
  fi
}

# Vérifier si SonarQube est accessible
echo "Vérification de l'accès à SonarQube..."
if ! curl -s "http://localhost:$SONAR_PORT/api/system/status" -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD" | grep -q "UP"; then
  echo "SonarQube n'est pas accessible. Vérifiez qu'il est bien démarré."
  exit 1
fi

# Changer le mot de passe administrateur
echo "Changement du mot de passe administrateur..."
call_api "POST" "users/change_password" "login=$SONAR_ADMIN_USER&previousPassword=$SONAR_ADMIN_PASSWORD&password=$SONAR_NEW_PASSWORD"

# Mettre à jour le mot de passe pour les appels suivants
SONAR_ADMIN_PASSWORD="$SONAR_NEW_PASSWORD"

# Créer un token pour l'API
echo "Création d'un token pour l'API..."
TOKEN_RESPONSE=$(curl -s -X "POST" -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD" "http://localhost:$SONAR_PORT/api/user_tokens/generate?name=github-actions")
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
  echo "Token créé avec succès"
  echo "Veuillez ajouter ce token comme secret GitHub avec le nom SONAR_TOKEN :"
  echo "$TOKEN"
else
  echo "Impossible de créer un token. Un token 'github-actions' existe peut-être déjà."
fi

# Créer les projets
echo "Création des projets SonarQube..."
curl -s -X "POST" -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD" "http://localhost:$SONAR_PORT/api/projects/create?name=YourMedia%20Backend&project=yourmedia-backend"
curl -s -X "POST" -u "$SONAR_ADMIN_USER:$SONAR_ADMIN_PASSWORD" "http://localhost:$SONAR_PORT/api/projects/create?name=YourMedia%20Mobile&project=yourmedia-mobile"

echo "Configuration de SonarQube terminée"
echo "URL de SonarQube : http://localhost:$SONAR_PORT"
echo "Utilisateur : $SONAR_ADMIN_USER"
echo "Mot de passe : $SONAR_NEW_PASSWORD"
echo "Token API : $TOKEN"

# Instructions pour GitHub Actions
echo ""
echo "Pour utiliser SonarQube avec GitHub Actions :"
echo "1. Ajoutez le token comme secret GitHub avec le nom SONAR_TOKEN"
echo "2. Assurez-vous que le port $SONAR_PORT est ouvert dans le groupe de sécurité de l'instance EC2"
echo "3. Utilisez l'URL http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):$SONAR_PORT dans vos workflows GitHub Actions"
