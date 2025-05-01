FROM prom/prometheus:latest

# Copier les fichiers de configuration
COPY ./prometheus.yml /etc/prometheus/prometheus.yml
COPY ./alerts.yml /etc/prometheus/alerts.yml
COPY ./container-alerts.yml /etc/prometheus/container-alerts.yml

# Exposer le port
EXPOSE 9090

# Définir les arguments de la commande
CMD [ "--config.file=/etc/prometheus/prometheus.yml", \
      "--storage.tsdb.path=/prometheus", \
      "--web.console.libraries=/usr/share/prometheus/console_libraries", \
      "--web.console.templates=/usr/share/prometheus/consoles", \
      "--web.enable-lifecycle" ]
