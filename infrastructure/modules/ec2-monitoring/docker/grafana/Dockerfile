FROM grafana/grafana:latest

# Utilisateur qui exécutera Grafana
USER root

# Copier les fichiers de configuration personnalisés
COPY provisioning /etc/grafana/provisioning
COPY dashboards /var/lib/grafana/dashboards

# Définir les variables d'environnement
ENV GF_SECURITY_ADMIN_PASSWORD=admin
ENV GF_USERS_ALLOW_SIGN_UP=false
ENV GF_AUTH_ANONYMOUS_ENABLED=true
ENV GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
ENV GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource

# Exposer le port
EXPOSE 3000

# Revenir à l'utilisateur grafana
USER grafana

# La commande de démarrage est héritée de l'image de base
