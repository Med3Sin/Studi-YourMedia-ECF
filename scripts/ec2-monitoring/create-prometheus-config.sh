#!/bin/bash
# Script pour créer la configuration Prometheus
# Ce script génère un fichier prometheus.yml avec la configuration correcte

set -e

# Rediriger stdout et stderr vers un fichier log
exec > >(tee -a /var/log/create-prometheus-config.log) 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Création de la configuration Prometheus"

# Créer le répertoire si nécessaire
sudo mkdir -p /opt/monitoring/config/prometheus
sudo mkdir -p /opt/monitoring/prometheus/rules

# Vérifier si l'adresse IP de l'instance Java Tomcat est disponible
JAVA_TOMCAT_IP=""
if [ -f "/opt/monitoring/secure/java-tomcat-ip.txt" ]; then
  JAVA_TOMCAT_IP=$(cat /opt/monitoring/secure/java-tomcat-ip.txt)
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Adresse IP de l'instance Java Tomcat trouvée: $JAVA_TOMCAT_IP"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Adresse IP de l'instance Java Tomcat non trouvée, utilisation de la valeur par défaut"
  # Tenter de détecter l'adresse IP de l'instance Java Tomcat via AWS CLI
  if command -v aws &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Tentative de détection de l'adresse IP de l'instance Java Tomcat via AWS CLI"
    # Rechercher l'instance EC2 avec le tag Name=yourmedia-dev-app-server
    JAVA_TOMCAT_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=yourmedia-dev-app-server" --query "Reservations[].Instances[].PrivateIpAddress" --output text)
    if [ -n "$JAVA_TOMCAT_IP" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Adresse IP de l'instance Java Tomcat détectée: $JAVA_TOMCAT_IP"
      echo "$JAVA_TOMCAT_IP" | sudo tee /opt/monitoring/secure/java-tomcat-ip.txt > /dev/null
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Impossible de détecter l'adresse IP de l'instance Java Tomcat via AWS CLI"
      JAVA_TOMCAT_IP="10.0.1.100"  # Valeur par défaut
    fi
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - AWS CLI non disponible, utilisation de la valeur par défaut"
    JAVA_TOMCAT_IP="10.0.1.100"  # Valeur par défaut
  fi
fi

# Créer le fichier de configuration Prometheus
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création du fichier prometheus.yml"
sudo bash -c "cat > /opt/monitoring/config/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  - \"/etc/prometheus/rules/*.yml\"

scrape_configs:
  - job_name: \"prometheus\"
    static_configs:
      - targets: [\"localhost:9090\"]

  - job_name: \"node-exporter\"
    static_configs:
      - targets: [\"node-exporter:9100\"]

  - job_name: \"cadvisor\"
    static_configs:
      - targets: [\"cadvisor:8080\"]

  - job_name: \"java-tomcat\"
    metrics_path: /metrics
    static_configs:
      - targets: [\"$JAVA_TOMCAT_IP:9100\"]
        labels:
          instance: \"java-tomcat\"
EOF"

# Créer un lien symbolique vers le fichier de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un lien symbolique vers le fichier prometheus.yml"
sudo ln -sf /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml

# Vérifier que le fichier a été créé
if [ -f "/opt/monitoring/config/prometheus/prometheus.yml" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Fichier prometheus.yml créé avec succès"
  cat /opt/monitoring/config/prometheus/prometheus.yml
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec de la création du fichier prometheus.yml"
fi

# Vérifier que le lien symbolique a été créé
if [ -L "/opt/monitoring/prometheus.yml" ] && [ -f "/opt/monitoring/prometheus.yml" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Lien symbolique prometheus.yml créé avec succès"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Échec de la création du lien symbolique prometheus.yml"
  # Créer une copie directe si le lien symbolique échoue
  sudo cp /opt/monitoring/config/prometheus/prometheus.yml /opt/monitoring/prometheus.yml
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration Prometheus terminée"
