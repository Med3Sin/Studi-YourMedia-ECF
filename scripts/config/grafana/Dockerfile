FROM grafana/grafana:latest

# Copier les fichiers de configuration
COPY ./dashboards /etc/grafana/dashboards
COPY ./datasources /etc/grafana/provisioning/datasources
COPY ./dashboards/default.yml /etc/grafana/provisioning/dashboards/default.yml
COPY ./logs-dashboard.json /var/lib/grafana/dashboards/logs-dashboard.json
COPY ./system-overview.json /var/lib/grafana/dashboards/system-overview.json

# Définir les variables d'environnement
# Le mot de passe administrateur sera fourni lors du déploiement via la variable d'environnement
# GF_SECURITY_ADMIN_PASSWORD ou GRAFANA_ADMIN_PASSWORD
ENV GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-admin}
ENV GF_USERS_ALLOW_SIGN_UP=false
ENV GF_AUTH_ANONYMOUS_ENABLED=true
ENV GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
ENV GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel

# Exposer le port
EXPOSE 3000

# Définir le point d'entrée
ENTRYPOINT ["/run.sh"]
