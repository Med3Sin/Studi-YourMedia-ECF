# YourMedia Backend

Ce répertoire contient le code source de l'application backend pour le projet YourMedia.

## Structure du projet

L'application est une application Java Spring Boot qui expose des API REST pour être consommées par le frontend.

```
app-java/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── yourmedia/
│   │   │           └── backend/
│   │   │               ├── Application.java
│   │   │               └── controller/
│   │   │                   └── HealthController.java
│   │   └── resources/
│   │       └── application.properties
│   └── test/
└── pom.xml
```

## Prérequis

- Java 17 ou supérieur
- Maven 3.8 ou supérieur
- MySQL 8.0 ou supérieur

## Compilation

Pour compiler l'application, exécutez la commande suivante :

```bash
mvn clean package
```

Cela générera un fichier WAR dans le répertoire `target/`.

## Déploiement

Le fichier WAR généré peut être déployé sur un serveur Tomcat 9 ou supérieur.

## Configuration

L'application peut être configurée via les variables d'environnement suivantes :

- `SPRING_DATASOURCE_URL` : URL de connexion à la base de données MySQL
- `SPRING_DATASOURCE_USERNAME` : Nom d'utilisateur pour la base de données
- `SPRING_DATASOURCE_PASSWORD` : Mot de passe pour la base de données

## Monitoring

L'application expose des endpoints Actuator pour le monitoring :

- `/actuator/health` : État de santé de l'application
- `/actuator/info` : Informations sur l'application
- `/actuator/prometheus` : Métriques au format Prometheus
