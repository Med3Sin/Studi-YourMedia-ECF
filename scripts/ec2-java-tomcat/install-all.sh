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

# Installation de JMX Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de JMX Exporter"
JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_DIR="/opt/yourmedia/monitoring"
sudo mkdir -p $JMX_EXPORTER_DIR

# Télécharger JMX Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement de JMX Exporter"
wget -q -O $JMX_EXPORTER_DIR/jmx_prometheus_javaagent.jar "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

# Créer le fichier de configuration JMX Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier de configuration JMX Exporter"
sudo bash -c "cat > $JMX_EXPORTER_DIR/jmx-config.yml << EOF
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: '.*'
EOF"

# Mettre à jour le service Tomcat pour inclure JMX Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Mise à jour du service Tomcat pour JMX Exporter"
sudo sed -i "s|Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC\"|Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC -javaagent:$JMX_EXPORTER_DIR/jmx_prometheus_javaagent.jar=9404:$JMX_EXPORTER_DIR/jmx-config.yml\"|" /etc/systemd/system/tomcat.service

# Installation de Promtail
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation de Promtail"
PROMTAIL_VERSION="2.9.3"
PROMTAIL_DIR="/opt/yourmedia/monitoring/promtail"
sudo mkdir -p $PROMTAIL_DIR

# Télécharger Promtail
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement de Promtail"
wget -q -O $PROMTAIL_DIR/promtail "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
unzip -q $PROMTAIL_DIR/promtail -d $PROMTAIL_DIR
sudo chmod +x $PROMTAIL_DIR/promtail-linux-amd64

# Créer le fichier de configuration Promtail
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier de configuration Promtail"
sudo bash -c "cat > $PROMTAIL_DIR/config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: tomcat
    static_configs:
      - targets:
          - localhost
        labels:
          job: tomcat
          __path__: /opt/tomcat/logs/*.log
EOF"

# Créer un service systemd pour Promtail
sudo bash -c 'cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
ExecStart=/opt/yourmedia/monitoring/promtail/promtail-linux-amd64 -config.file=/opt/yourmedia/monitoring/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Démarrer Promtail
sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail

# Redémarrer Tomcat pour appliquer les changements JMX Exporter
echo "$(date '+%Y-%m-%d %H:%M:%S') - Redémarrage de Tomcat pour appliquer JMX Exporter"
sudo systemctl restart tomcat

# Vérifier que JMX Exporter est accessible
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de JMX Exporter"
sleep 10
if curl -s http://localhost:9404/metrics | grep -q "jvm_"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ JMX Exporter est accessible et fonctionne"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️ JMX Exporter n'est pas accessible, vérifiez les logs de Tomcat"
fi

# Vérifier que Promtail est accessible
echo "$(date '+%Y-%m-%d %H:%M:%S') - Vérification de Promtail"
if curl -s http://localhost:9080/ready; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Promtail est accessible et fonctionne"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️ Promtail n'est pas accessible, vérifiez les logs"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script d'installation complet terminé"