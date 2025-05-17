FROM grafana/grafana:latest

# Créer les répertoires nécessaires
RUN mkdir -p /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards

# Copier les fichiers de configuration
COPY ./datasources /etc/grafana/provisioning/datasources
COPY ./dashboards/default.yml /etc/grafana/provisioning/dashboards/default.yml

# Copier les tableaux de bord
COPY ./logs-dashboard.json /var/lib/grafana/dashboards/logs-dashboard.json
COPY ./system-overview.json /var/lib/grafana/dashboards/system-overview.json
COPY ./java-app-logs-dashboard.json /var/lib/grafana/dashboards/java-app-logs.json
COPY ./react-app-dashboard.json /var/lib/grafana/dashboards/react-app-dashboard.json

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
