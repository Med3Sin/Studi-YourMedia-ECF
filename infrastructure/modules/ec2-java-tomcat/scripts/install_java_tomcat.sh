#!/bin/bash -xe
# Script d'installation pour Java (OpenJDK 17) et Tomcat 9 sur Amazon Linux 2
# Exécuté en tant que root via user_data

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Mise à jour des paquets ---"
sudo yum update -y

echo "--- Configuration des clés SSH ---"
# Créer le répertoire .ssh s'il n'existe pas
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Créer le fichier authorized_keys s'il n'existe pas
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Récupérer la clé publique depuis les métadonnées de l'instance
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key)
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
fi

echo "--- Installation d'AWS CLI ---"
if ! command -v aws &> /dev/null; then
    echo "Installation d'AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo yum install -y unzip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    # Vérifier l'installation
    aws --version
fi

echo "--- Installation de Java (Amazon Corretto 17) ---"
sudo amazon-linux-extras enable corretto17
sudo yum install -y java-17-amazon-corretto-devel

# Vérifier l'installation de Java
java -version

echo "--- Création de l'utilisateur et groupe Tomcat ---"
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

echo "--- Téléchargement et Extraction de Tomcat 9 ---"
# La version de Tomcat est passée via la variable TOMCAT_VERSION depuis le template Terraform
# Si non définie, utiliser une valeur par défaut
TOMCAT_VERSION="${TOMCAT_VERSION}"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

cd /tmp
wget $TOMCAT_URL

sudo mkdir /opt/tomcat
sudo tar xzvf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1

echo "--- Configuration des Permissions Tomcat ---"
cd /opt/tomcat
sudo chgrp -R tomcat /opt/tomcat
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R tomcat webapps/ work/ temp/ logs/

echo "--- Création du fichier de service Systemd pour Tomcat ---"
sudo bash -c 'cat > /etc/systemd/system/tomcat.service' << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

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

echo "--- Rechargement de Systemd et Démarrage de Tomcat ---"
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat # Activer le démarrage automatique au boot

# Vérifier le statut de Tomcat (optionnel, pour le log)
sudo systemctl status tomcat

echo "--- Installation de Node Exporter pour Prometheus ---"
# Télécharger et installer Node Exporter pour la surveillance Prometheus
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter

# Créer un service systemd pour Node Exporter
sudo bash -c 'cat > /etc/systemd/system/node_exporter.service' << EOF
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
EOF

# Démarrer et activer Node Exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Vérifier le statut de Node Exporter
sudo systemctl status node_exporter

echo "--- Installation terminée ---"
