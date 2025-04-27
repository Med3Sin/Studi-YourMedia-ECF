#!/bin/bash
# Script d'installation pour Java (Amazon Corretto 17) et Tomcat 9 sur Amazon Linux 2023
# Exécuté en tant que root via user_data

# Activer le mode de débogage et la sortie d'erreur en cas d'échec
set -e

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Fonction pour afficher les messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Fonction pour afficher les erreurs et quitter
error_exit() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier que les variables d'environnement nécessaires sont définies
if [ -z "$TOMCAT_VERSION" ]; then
    log "La variable TOMCAT_VERSION n'est pas définie, utilisation de la valeur par défaut 9.0.104"
    TOMCAT_VERSION="9.0.104"
fi

log "Démarrage de l'installation de Java et Tomcat $TOMCAT_VERSION"

echo "--- Mise à jour des paquets ---"
sudo dnf update -y

echo "--- Configuration des clés SSH ---"
# Créer le répertoire .ssh pour ec2-user
sudo mkdir -p /home/ec2-user/.ssh
sudo chmod 700 /home/ec2-user/.ssh

# Créer le fichier authorized_keys s'il n'existe pas
sudo touch /home/ec2-user/.ssh/authorized_keys
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
  local ssh_dir="$1"
  echo "Vérification et correction des clés SSH dans $ssh_dir..."

  # Vérifier si le fichier authorized_keys existe
  if [ ! -f "$ssh_dir/authorized_keys" ]; then
    echo "Le fichier authorized_keys n'existe pas. Rien à faire."
    return
  fi

  # Sauvegarder le fichier original
  sudo cp "$ssh_dir/authorized_keys" "$ssh_dir/authorized_keys.bak"

  # Supprimer les guillemets simples dans le fichier authorized_keys
  sudo sed "s/'//g" "$ssh_dir/authorized_keys.bak" > "$ssh_dir/authorized_keys.tmp"

  # Vérifier le format des clés SSH
  sudo touch "$ssh_dir/authorized_keys.new"
  sudo chmod 600 "$ssh_dir/authorized_keys.new"
  while IFS= read -r line; do
    # Ignorer les lignes vides ou commentées
    if [[ -z "$line" || "$line" == \#* ]]; then
      echo "$line" >> "$ssh_dir/authorized_keys.new"
      continue
    fi

    # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
    if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
      echo "$line" >> "$ssh_dir/authorized_keys.new"
    else
      # Si la ligne ne commence pas par un type de clé SSH valide,
      # vérifier si elle contient un type de clé SSH valide
      if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        # Extraire la partie qui commence par le type de clé SSH
        key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
        echo "$key_part" >> "$ssh_dir/authorized_keys.new"
      else
        # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
        echo "Ligne ignorée (format non reconnu): $line"
      fi
    fi
  done < "$ssh_dir/authorized_keys.tmp"

  # Remplacer le fichier authorized_keys
  sudo mv "$ssh_dir/authorized_keys.new" "$ssh_dir/authorized_keys"

  # Ajuster les permissions
  sudo chmod 600 "$ssh_dir/authorized_keys"

  # Supprimer les fichiers temporaires
  sudo rm -f "$ssh_dir/authorized_keys.tmp"

  echo "Correction des clés SSH terminée."
}

# Ajouter la clé SSH publique fournie par Terraform
SSH_PUBLIC_KEY="${ssh_public_key}"
if [ ! -z "$SSH_PUBLIC_KEY" ]; then
  # Supprimer les guillemets simples qui pourraient être présents dans la clé
  CLEAN_KEY=$(echo "$SSH_PUBLIC_KEY" | sed "s/'//g")
  echo "$CLEAN_KEY" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
  echo "Clé SSH publique GitHub installée avec succès"

  # Corriger les clés SSH
  fix_ssh_keys "/home/ec2-user/.ssh"
fi

# Créer un service systemd pour vérifier périodiquement les clés SSH
cat > /tmp/fix-ssh-keys.sh << EOF
#!/bin/bash
# Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys

$(declare -f fix_ssh_keys)

# Exécuter la fonction de correction
fix_ssh_keys ~/.ssh
EOF

sudo chmod +x /tmp/fix-ssh-keys.sh
sudo cp /tmp/fix-ssh-keys.sh /usr/local/bin/fix-ssh-keys.sh

# Créer un service systemd pour exécuter le script périodiquement
sudo bash -c 'cat > /etc/systemd/system/ssh-key-checker.service << "EOF"'
[Unit]
Description=SSH Key Format Checker
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-ssh-keys.sh
User=ec2-user
Group=ec2-user
EOF

sudo bash -c 'cat > /etc/systemd/system/ssh-key-checker.timer << "EOF"'
[Unit]
Description=Run SSH Key Format Checker periodically

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOF

# Activer et démarrer le timer
systemctl daemon-reload
systemctl enable ssh-key-checker.timer
systemctl start ssh-key-checker.timer

# Récupérer également la clé publique depuis les métadonnées de l'instance (si disponible)
PUBLIC_KEY=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key 2>/dev/null || echo "")
if [ ! -z "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" | sudo tee -a /home/ec2-user/.ssh/authorized_keys > /dev/null
  echo "Clé SSH publique AWS installée avec succès"
fi

# Ajuster les permissions
sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh

echo "--- Installation d'AWS CLI ---"
if ! command -v aws &> /dev/null; then
    echo "Installation d'AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo dnf install -y unzip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    # Vérifier l'installation
    aws --version
fi

echo "--- Installation de Java (Amazon Corretto 17) ---"
sudo dnf install -y java-17-amazon-corretto-devel

# Vérifier l'installation de Java
java -version

echo "--- Création de l'utilisateur et groupe Tomcat ---"
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

echo "--- Téléchargement et Extraction de Tomcat 9 ---"
# La version de Tomcat est passée via la variable TOMCAT_VERSION depuis le template Terraform
# Si non définie, utiliser une valeur par défaut (9.0.87)
TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.87}"
echo "Installation de Tomcat version: $TOMCAT_VERSION"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

cd /tmp
wget $TOMCAT_URL || error_exit "Échec du téléchargement de Tomcat"

# Vérifier que le téléchargement a réussi
if [ ! -f "/tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz" ]; then
  error_exit "Le fichier apache-tomcat-${TOMCAT_VERSION}.tar.gz n'a pas été téléchargé"
fi

# Créer le répertoire Tomcat s'il n'existe pas
sudo mkdir -p /opt/tomcat

# Extraire l'archive
sudo tar xzvf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1 || error_exit "Échec de l'extraction de Tomcat"

# Vérifier que l'extraction a réussi
if [ ! -f "/opt/tomcat/bin/startup.sh" ]; then
  error_exit "L'extraction de Tomcat a échoué, le fichier startup.sh est introuvable"
fi

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

echo "--- Exécution du script de correction des clés SSH ---"
# Exécuter le script en tant qu'utilisateur ec2-user
su - ec2-user -c "/usr/local/bin/fix-ssh-keys.sh"

echo "--- Vérification du script de déploiement WAR ---"
# Vérifier si le script de déploiement WAR existe déjà dans /opt/yourmedia
if [ ! -f "/opt/yourmedia/deploy-war.sh" ]; then
  echo "Le script deploy-war.sh n'existe pas dans /opt/yourmedia. Création du script..."
  # Créer le script de déploiement WAR
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
  echo "Script de déploiement WAR créé dans /opt/yourmedia/deploy-war.sh"
else
  echo "Le script deploy-war.sh existe déjà dans /opt/yourmedia. Utilisation du script existant."
fi

# Créer un lien symbolique vers le script dans /usr/local/bin pour le rendre accessible globalement
if [ ! -f "/usr/local/bin/deploy-war.sh" ]; then
  ln -s /opt/yourmedia/deploy-war.sh /usr/local/bin/deploy-war.sh
  chmod +x /usr/local/bin/deploy-war.sh
  chown root:root /usr/local/bin/deploy-war.sh
  echo "Lien symbolique créé dans /usr/local/bin/deploy-war.sh"
else
  echo "Le lien symbolique /usr/local/bin/deploy-war.sh existe déjà."
fi

# Configurer sudoers pour permettre à ec2-user d'exécuter le script sans mot de passe
echo "ec2-user ALL=(ALL) NOPASSWD: /usr/local/bin/deploy-war.sh" > /etc/sudoers.d/deploy-war
chmod 440 /etc/sudoers.d/deploy-war

echo "--- Installation terminée ---"
