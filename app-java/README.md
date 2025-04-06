# Application Backend - Java Spring Boot (app-java)

Ce répertoire contient le code source de l'application backend de YourMédia, développée avec Java et Spring Boot.

## Fonctionnalités (Placeholder)

*   **API REST "Hello World"**: Expose un endpoint `/` qui retourne un message simple.
*   **Packaging WAR**: L'application est configurée pour être packagée en tant que fichier `.war` (nommé `yourmedia-backend.war`) pour être déployée dans un conteneur de servlets externe (Tomcat).
*   **Actuator & Prometheus**: Intègre Spring Boot Actuator pour exposer des endpoints de gestion, notamment `/actuator/health` et `/actuator/prometheus` pour la collecte de métriques par Prometheus.

## Prérequis pour le Développement Local

*   Java JDK 17 ou supérieur
*   Maven 3.x

## Build

Pour construire l'application et générer le fichier `.war` :

```bash
# Depuis la racine du projet global
mvn clean package -f app-java/pom.xml

# Ou en étant dans le dossier app-java
cd app-java
mvn clean package
```

Le fichier `yourmedia-backend.war` sera généré dans le répertoire `app-java/target/`.

## Configuration

La configuration principale se trouve dans `src/main/resources/application.properties`.

*   `server.servlet.context-path=/yourmedia-backend`: Définit le chemin racine de l'API.
*   `management.endpoints.web.exposure.include=health,prometheus`: Expose les endpoints Actuator nécessaires.

## Déploiement

Le déploiement est automatisé via le workflow GitHub Actions `3-backend-deploy.yml`. Ce workflow :
1.  Compile et package l'application (`mvn package`).
2.  Upload le `.war` sur le bucket S3 configuré.
3.  Se connecte en SSH à l'instance EC2.
4.  Copie le `.war` depuis S3 vers le répertoire `webapps` de Tomcat sur l'EC2.
5.  Tomcat détecte automatiquement le nouveau `.war` et déploie l'application.

L'application sera accessible à l'URL : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/`
Les métriques Prometheus seront disponibles à : `http://<IP_PUBLIQUE_EC2>:8080/yourmedia-backend/actuator/prometheus` (accessible uniquement depuis le réseau interne par Prometheus sur ECS).
