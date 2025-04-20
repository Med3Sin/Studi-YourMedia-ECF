FROM prom/prometheus:latest

# Copier les fichiers de configuration personnalisés
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY rules/*.yml /etc/prometheus/rules/

# Exposer le port
EXPOSE 9090

# Commande de démarrage avec les options personnalisées
CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
      "--storage.tsdb.path=/prometheus", \
      "--storage.tsdb.retention.time=15d", \
      "--storage.tsdb.retention.size=1GB", \
      "--web.console.libraries=/usr/share/prometheus/console_libraries", \
      "--web.console.templates=/usr/share/prometheus/consoles" ]
