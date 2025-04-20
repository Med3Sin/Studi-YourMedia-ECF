#!/bin/bash -xe
# Script d'installation pour Java (OpenJDK 17) et Tomcat 9 sur Amazon Linux 2
# Exécuté en tant que root via user_data

# Rediriger stdout et stderr vers un fichier log pour le débogage
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Mise à jour des paquets ---"
sudo yum update -y

echo "--- Configuration des clés SSH ---"
# Créer le répertoire .ssh pour ec2-user
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Créer le fichier authorized_keys s'il n'existe pas
touch /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
  echo "Vérification et correction des clés SSH..."

  # Vérifier si le fichier authorized_keys existe
  if [ ! -f /home/ec2-user/.ssh/authorized_keys ]; then
    echo "Le fichier authorized_keys n'existe pas. Rien à faire."
    return
  fi

  # Sauvegarder le fichier original
  cp /home/ec2-user/.ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys.bak

  # Supprimer les guillemets simples dans le fichier authorized_keys
  sed "s/'//g" /home/ec2-user/.ssh/authorized_keys.bak > /home/ec2-user/.ssh/authorized_keys.tmp

  # Vérifier le format des clés SSH
  > /home/ec2-user/.ssh/authorized_keys.new
  while IFS= read -r line; do
    # Ignorer les lignes vides ou commentées
    if [[ -z "$line" || "$line" == \#* ]]; then
      echo "$line" >> /home/ec2-user/.ssh/authorized_keys.new
      continue
    fi

    # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
    if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
      echo "$line" >> /home/ec2-user/.ssh/authorized_keys.new
    else
      # Si la ligne ne commence pas par un type de clé SSH valide,
      # vérifier si elle contient un type de clé SSH valide
      if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        # Extraire la partie qui commence par le type de clé SSH
        key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
        echo "$key_part" >> /home/ec2-user/.ssh/authorized_keys.new
      else
        # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
        echo "Ligne ignorée (format non reconnu): $line"
      fi
    fi
  done < /home/ec2-user/.ssh/authorized_keys.tmp

  # Remplacer le fichier authorized_keys
  mv /home/ec2-user/.ssh/authorized_keys.new /home/ec2-user/.ssh/authorized_keys

  # Ajuster les permissions
  chmod 600 /home/ec2-user/.ssh/authorized_keys

  # Supprimer les fichiers temporaires
  rm -f /home/ec2-user/.ssh/authorized_keys.tmp

  echo "Correction des clés SSH terminée."
}

# Ajouter la clé SSH publique fournie par Terraform
SSH_PUBLIC_KEY="${ssh_public_key}"
if [ ! -z "$SSH_PUBLIC_KEY" ]; then
  # Supprimer les guillemets simples qui pourraient être présents dans la clé
  CLEAN_KEY=$(echo "$SSH_PUBLIC_KEY" | sed "s/'//g")
  echo "$CLEAN_KEY" >> /home/ec2-user/.ssh/authorized_keys
  echo "Clé SSH publique GitHub installée avec succès"

  # Corriger les clés SSH
  fix_ssh_keys
fi

# Créer un service systemd pour vérifier périodiquement les clés SSH
cat > /tmp/fix-ssh-keys.sh << 'EOF'
#!/bin/bash
# Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
  echo "Vérification et correction des clés SSH..."

  # Vérifier si le fichier authorized_keys existe
  if [ ! -f ~/.ssh/authorized_keys ]; then
    echo "Le fichier authorized_keys n'existe pas. Rien à faire."
    return
  fi

  # Sauvegarder le fichier original
  cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

  # Supprimer les guillemets simples dans le fichier authorized_keys
  sed "s/'//g" ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys.tmp

  # Vérifier le format des clés SSH
  > ~/.ssh/authorized_keys.new
  while IFS= read -r line; do
    # Ignorer les lignes vides ou commentées
    if [[ -z "$line" || "$line" == \#* ]]; then
      echo "$line" >> ~/.ssh/authorized_keys.new
      continue
    fi

    # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
    if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
      echo "$line" >> ~/.ssh/authorized_keys.new
    else
      # Si la ligne ne commence pas par un type de clé SSH valide,
      # vérifier si elle contient un type de clé SSH valide
      if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        # Extraire la partie qui commence par le type de clé SSH
        key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
        echo "$key_part" >> ~/.ssh/authorized_keys.new
      else
        # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
        echo "Ligne ignorée (format non reconnu): $line"
      fi
    fi
  done < ~/.ssh/authorized_keys.tmp

  # Remplacer le fichier authorized_keys
  mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys

  # Ajuster les permissions
  chmod 600 ~/.ssh/authorized_keys

  # Supprimer les fichiers temporaires
  rm -f ~/.ssh/authorized_keys.tmp

  echo "Correction des clés SSH terminée."
}

# Exécuter la fonction de correction
fix_ssh_keys
EOF

chmod +x /tmp/fix-ssh-keys.sh
cp /tmp/fix-ssh-keys.sh /usr/local/bin/fix-ssh-keys.sh

# Créer un service systemd pour exécuter le script périodiquement
cat > /etc/systemd/system/ssh-key-checker.service << 'EOF'
[Unit]
Description=SSH Key Format Checker
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-ssh-keys.sh
User=ec2-user
Group=ec2-user
EOF

cat > /etc/systemd/system/ssh-key-checker.timer << 'EOF'
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
  echo "$PUBLIC_KEY" >> /home/ec2-user/.ssh/authorized_keys
  echo "Clé SSH publique AWS installée avec succès"
fi

# Ajuster les permissions
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

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

echo "--- Installation du script de correction des clés SSH ---"
# Créer le script de correction des clés SSH
cat > /tmp/fix_ssh_keys.sh << 'EOFFIX'
#!/bin/bash
# Script pour vérifier et corriger les clés SSH dans le fichier authorized_keys
# Ce script supprime les guillemets simples qui entourent les clés SSH

# Fonction pour corriger les clés SSH
fix_ssh_keys() {
    echo "[INFO] Vérification et correction des clés SSH..."

    # Vérifier si le fichier authorized_keys existe
    if [ ! -f ~/.ssh/authorized_keys ]; then
        echo "[WARN] Le fichier authorized_keys n'existe pas. Rien à faire."
        return
    fi

    # Sauvegarder le fichier original
    cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

    # Supprimer les guillemets simples dans le fichier authorized_keys
    sed "s/'//g" ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys.tmp

    # Vérifier le format des clés SSH
    > ~/.ssh/authorized_keys.new
    while IFS= read -r line; do
        # Ignorer les lignes vides ou commentées
        if [[ -z "$line" || "$line" == \#* ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
            continue
        fi

        # Vérifier si la ligne commence par ssh-rsa, ssh-ed25519, etc.
        if [[ "$line" =~ ^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
            echo "$line" >> ~/.ssh/authorized_keys.new
        else
            # Si la ligne ne commence pas par un type de clé SSH valide,
            # vérifier si elle contient un type de clé SSH valide
            if [[ "$line" =~ (ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
                # Extraire la partie qui commence par le type de clé SSH
                key_part=$(echo "$line" | grep -o "ssh-[^ ]*.*")
                echo "$key_part" >> ~/.ssh/authorized_keys.new
            else
                # Si la ligne ne contient pas de type de clé SSH valide, l'ignorer
                echo "[WARN] Ligne ignorée (format non reconnu): $line"
            fi
        fi
    done < ~/.ssh/authorized_keys.tmp

    # Remplacer le fichier authorized_keys
    mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys

    # Ajuster les permissions
    chmod 600 ~/.ssh/authorized_keys

    # Supprimer les fichiers temporaires
    rm -f ~/.ssh/authorized_keys.tmp

    echo "[INFO] Correction des clés SSH terminée."
}

# Exécuter la fonction de correction
fix_ssh_keys
EOFFIX

# Rendre le script exécutable
chmod +x /tmp/fix_ssh_keys.sh

# Exécuter le script en tant qu'utilisateur ec2-user
su - ec2-user -c "/tmp/fix_ssh_keys.sh"

# Copier le script dans /usr/local/bin pour une utilisation future
sudo cp /tmp/fix_ssh_keys.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/fix_ssh_keys.sh

# Créer un service systemd pour exécuter le script périodiquement
sudo bash -c 'cat > /etc/systemd/system/ssh-key-checker.service' << EOF
[Unit]
Description=SSH Key Format Checker
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix_ssh_keys.sh
User=ec2-user
Group=ec2-user
EOF

sudo bash -c 'cat > /etc/systemd/system/ssh-key-checker.timer' << EOF
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
sudo systemctl daemon-reload
sudo systemctl enable ssh-key-checker.timer
sudo systemctl start ssh-key-checker.timer

echo "--- Installation terminée ---"
