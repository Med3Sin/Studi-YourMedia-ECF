FROM grafana/promtail:2.9.2

# Copier la configuration personnalisée
COPY promtail-config.yml /etc/promtail/config.yml

# Exposer le port
EXPOSE 9080

# Commande par défaut
ENTRYPOINT ["/usr/bin/promtail"]
CMD ["-config.file=/etc/promtail/config.yml"]
