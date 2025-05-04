FROM grafana/loki:2.9.2

# Copier la configuration personnalisée
COPY loki-config.yml /etc/loki/local-config.yaml

# Créer les répertoires nécessaires
RUN mkdir -p /loki/chunks /loki/index && \
    chmod -R 777 /loki

# Exposer le port
EXPOSE 3100

# Commande par défaut
ENTRYPOINT ["/usr/bin/loki"]
CMD ["-config.file=/etc/loki/local-config.yaml"]
