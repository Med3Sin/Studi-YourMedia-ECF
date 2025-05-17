#!/bin/bash
# Script d'installation complet pour l'instance EC2 Java Tomcat
# Ce script installe Java, Tomcat et node_exporter

set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee -a /var/log/install-all.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage du script d'installation complet"

# Mettre à jour le système
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du système"
sudo dnf update -y

# Installer les dépendances nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des dépendances"

# Vérifier si curl-minimal est installé
if rpm -q curl-minimal > /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - curl-minimal est installé, résolution du conflit de packages"

  # Tenter d'installer curl avec --allowerasing pour résoudre le conflit
  sudo dnf install -y --allowerasing curl

  # Vérifier si l'installation a réussi
  if ! rpm -q curl > /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Échec de l'installation de curl avec --allowerasing, tentative alternative"

    # Tenter de supprimer curl-minimal d'abord
    sudo dnf remove -y curl-minimal
    sudo dnf install -y curl
  fi
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - curl-minimal n'est pas installé, installation normale de curl"
  sudo dnf install -y curl
fi

# Installer les autres dépendances
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation des autres dépendances"
sudo dnf install -y jq wget aws-cli net-tools

# Installer Java avec --allowerasing pour éviter les conflits
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Java"
sudo dnf install -y --allowerasing java-17-amazon-corretto-devel

# Créer les répertoires nécessaires
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création des répertoires nécessaires"
sudo mkdir -p /opt/yourmedia/secure
sudo mkdir -p /opt/tomcat
sudo chmod 755 /opt/yourmedia
sudo chmod 700 /opt/yourmedia/secure

# Récupérer l'ID de l'instance pour les logs
echo "$(date '+%Y-%m-%d %H:%M:%S') - Récupération de l'ID de l'instance"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "ID de l'instance: $INSTANCE_ID"

# Trouver le chemin correct de Java
echo "$(date '+%Y-%m-%d %H:%M:%S') - Recherche du chemin Java"
JAVA_HOME_PATH=$(find /usr/lib/jvm -name "java-17-amazon-corretto*" -type d | head -n 1)
if [ -z "$JAVA_HOME_PATH" ]; then
    JAVA_HOME_PATH="/usr/lib/jvm/java-17-amazon-corretto.x86_64"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Chemin Java non trouvé, utilisation de la valeur par défaut: $JAVA_HOME_PATH"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Chemin Java trouvé: $JAVA_HOME_PATH"
fi

# Création du fichier de service Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier de service Tomcat"
sudo bash -c "cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC\"
Environment=\"JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom\"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

# Télécharger et installer Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement et installation de Tomcat"

# Détection automatique de la dernière version de Tomcat 9
echo "$(date '+%Y-%m-%d %H:%M:%S') - Détection de la dernière version de Tomcat 9"
TOMCAT_VERSION_PAGE=$(curl -s https://dlcdn.apache.org/tomcat/tomcat-9/)
LATEST_VERSION=$(echo "$TOMCAT_VERSION_PAGE" | grep -o 'v9\.[0-9]\+\.[0-9]\+' | sort -V | tail -n 1 | sed 's/v//')

if [ -n "$LATEST_VERSION" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Dernière version de Tomcat 9 détectée: $LATEST_VERSION"
  TOMCAT_VERSION=$LATEST_VERSION
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Impossible de détecter la dernière version, utilisation de la version par défaut"
  TOMCAT_VERSION=9.0.105  # Version par défaut en cas d'échec de la détection
fi

cd /tmp

# Télécharger Tomcat
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement de Tomcat $TOMCAT_VERSION"
DOWNLOAD_SUCCESS=false
TOMCAT_URLS=(
  "https://dlcdn.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  "https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
  "https://downloads.apache.org/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
)

for URL in "${TOMCAT_URLS[@]}"; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative de téléchargement depuis: $URL"
  wget -q -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz "$URL"

  if [ -s /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Téléchargement réussi depuis: $URL"
    DOWNLOAD_SUCCESS=true
    break
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du téléchargement depuis: $URL"
  fi
done

# Si le téléchargement a échoué, essayer avec une version alternative
if [ "$DOWNLOAD_SUCCESS" = false ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du téléchargement de Tomcat $TOMCAT_VERSION, tentative avec une version alternative"
  TOMCAT_VERSION=9.0.78
  URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative de téléchargement depuis: $URL"
  wget -q -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz "$URL"

  if [ -s /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Téléchargement réussi depuis: $URL"
    DOWNLOAD_SUCCESS=true
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec du téléchargement de Tomcat"
  fi
fi

# Extraire Tomcat
if [ "$DOWNLOAD_SUCCESS" = true ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Extraction de Tomcat"
  sudo mkdir -p /opt/tomcat
  sudo tar xzf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C /opt/tomcat --strip-components=1

  # Créer un utilisateur Tomcat
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de l'utilisateur Tomcat"
  sudo useradd -r -m -d /opt/tomcat -s /bin/false tomcat || true

  # Configuration des permissions
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration des permissions"
  sudo chown -R tomcat:tomcat /opt/tomcat
  sudo chmod +x /opt/tomcat/bin/*.sh

  # Démarrer Tomcat
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage de Tomcat"
  sudo systemctl daemon-reload
  sudo systemctl start tomcat
  sudo systemctl enable tomcat
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Impossible d'installer Tomcat car le téléchargement a échoué"
fi

# Télécharger le script de déploiement WAR
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script de déploiement WAR"
sudo wget -q -O /opt/yourmedia/deploy-war.sh "https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main/scripts/ec2-java-tomcat/deploy-war.sh"
sudo chmod +x /opt/yourmedia/deploy-war.sh
sudo ln -sf /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh

# Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
sudo bash -c 'echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war'
sudo chmod 440 /etc/sudoers.d/deploy-war

# Installation de node_exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de node_exporter"
NODE_EXPORTER_VERSION="1.7.0"
wget -q -O /tmp/node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
sudo tar xzf /tmp/node_exporter.tar.gz -C /tmp
sudo mv /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter || true

# Créer un service systemd pour node_exporter
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

# Démarrer node_exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Ouvrir le port 9100 pour node_exporter dans le pare-feu
if command -v firewall-cmd &> /dev/null; then
  sudo firewall-cmd --permanent --add-port=9100/tcp
  sudo firewall-cmd --reload
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'installation complet terminé"
