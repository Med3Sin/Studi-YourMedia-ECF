FROM sonarqube:community

# Utilisateur qui exécutera SonarQube
USER root

# Installer des outils supplémentaires
RUN apt-get update && apt-get install -y curl unzip

# Télécharger et installer des plugins supplémentaires
RUN mkdir -p /opt/sonarqube/extensions/plugins/tmp && \
    cd /opt/sonarqube/extensions/plugins/tmp && \
    curl -L -O https://github.com/SonarSource/sonar-java/releases/download/7.16.0.30901/sonar-java-plugin-7.16.0.30901.jar && \
    curl -L -O https://github.com/SonarSource/sonar-javascript/releases/download/9.7.0.18911/sonar-javascript-plugin-9.7.0.18911.jar && \
    curl -L -O https://github.com/SonarSource/sonar-python/releases/download/3.24.0.10784/sonar-python-plugin-3.24.0.10784.jar && \
    mv *.jar /opt/sonarqube/extensions/plugins/ && \
    rm -rf /opt/sonarqube/extensions/plugins/tmp

# Copier les fichiers de configuration personnalisés
COPY sonar.properties /opt/sonarqube/conf/sonar.properties

# Exposer le port
EXPOSE 9000

# Revenir à l'utilisateur sonarqube
USER sonarqube

# La commande de démarrage est héritée de l'image de base
