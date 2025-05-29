# YourMedia Backend

Application backend Java/Spring Boot pour la plateforme YourMedia.

## Prérequis

- Java 17
- Maven 3.8+
- Tomcat 9
- MySQL 8.0

## Structure du projet

```
app-java/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── yourmedia/
│   │   │           └── backend/
│   │   │               ├── controller/
│   │   │               ├── service/
│   │   │               ├── model/
│   │   │               └── Application.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/
└── pom.xml
```

## Configuration

### application.yml
```yaml
server:
  port: 8080

spring:
  application:
    name: yourmedia-backend

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### Dépendances principales

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

## Développement

1. Cloner le repository :
```bash
git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git
cd Studi-YourMedia-ECF/app-java
```

2. Installer les dépendances :
```bash
mvn clean install
```

3. Lancer l'application :
```bash
mvn spring-boot:run
```

## Build et déploiement

1. Générer le WAR :
```bash
mvn clean package
```

2. Déployer sur Tomcat :
```bash
./deploy-war.sh target/backend.war
```

## API Endpoints

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | /api/media | Liste des médias |
| GET | /api/media/{id} | Détails média |
| POST | /api/media | Création média |
| PUT | /api/media/{id} | Mise à jour |
| DELETE | /api/media/{id} | Suppression |

## Monitoring

L'application expose les endpoints suivants pour le monitoring :

- `/actuator/health` - État de l'application
- `/actuator/info` - Informations générales
- `/actuator/prometheus` - Métriques Prometheus

## Tests

```bash
# Exécuter tous les tests
mvn test

# Exécuter un test spécifique
mvn test -Dtest=MediaServiceTest
```

## Documentation

Pour plus de détails, consultez :
- [Documentation Spring Boot](https://spring.io/projects/spring-boot)
- [Documentation Micrometer](https://micrometer.io/docs)
- [Documentation Prometheus](https://prometheus.io/docs)
