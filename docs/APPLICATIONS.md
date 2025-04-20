# Applications - YourMédia

Ce document centralise toute la documentation relative aux applications backend (Java) et frontend (React) du projet YourMédia.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Application Backend (Java)](#application-backend-java)
   - [Structure du projet](#structure-du-projet-backend)
   - [Configuration](#configuration-backend)
   - [API REST](#api-rest)
   - [Accès à la base de données](#accès-à-la-base-de-données)
   - [Accès au stockage S3](#accès-au-stockage-s3)
3. [Application Frontend (React)](#application-frontend-react)
   - [Structure du projet](#structure-du-projet-frontend)
   - [Configuration](#configuration-frontend)
   - [Composants principaux](#composants-principaux)
   - [Intégration avec l'API](#intégration-avec-lapi)
4. [Déploiement des applications](#déploiement-des-applications)
   - [Déploiement du backend](#déploiement-du-backend)
   - [Déploiement du frontend](#déploiement-du-frontend)
5. [Corrections et améliorations](#corrections-et-améliorations)

## Vue d'ensemble

Le projet YourMédia est composé de deux applications principales :

1. **Backend** : Une application Java déployée sur Tomcat qui expose une API REST pour la gestion des médias.
2. **Frontend** : Une application React Native Web conteneurisée avec Docker qui fournit l'interface utilisateur.

Ces deux applications communiquent via des appels API REST et utilisent les services AWS (RDS, S3) pour le stockage des données et des médias. Les deux applications sont déployées sur des instances EC2 via des conteneurs Docker.

## Application Backend (Java)

L'application backend est développée en Java avec le framework Spring Boot. Elle expose une API REST pour l'application frontend et utilise MySQL comme base de données.

### Structure du projet backend

```
app-java/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── yourmedia/
│   │   │           ├── controller/    # Contrôleurs REST
│   │   │           ├── model/         # Entités JPA
│   │   │           ├── repository/    # Repositories JPA
│   │   │           ├── service/       # Services métier
│   │   │           ├── config/        # Configuration
│   │   │           └── Application.java
│   │   └── resources/
│   │       ├── application.properties # Configuration de l'application
│   │       ├── static/                # Ressources statiques
│   │       └── templates/             # Templates Thymeleaf
│   └── test/                          # Tests unitaires et d'intégration
├── pom.xml                            # Configuration Maven
└── README.md                          # Documentation spécifique
```

### Configuration backend

La configuration de l'application est définie dans le fichier `application.properties` :

```properties
# Configuration de la base de données
spring.datasource.url=jdbc:mysql://${DB_HOST}:3306/${DB_NAME}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect

# Configuration S3
aws.s3.bucket=${S3_BUCKET_NAME}
aws.region=eu-west-3

# Configuration de l'application
server.port=8080
spring.servlet.multipart.max-file-size=10MB
spring.servlet.multipart.max-request-size=10MB
```

Les variables d'environnement (`DB_HOST`, `DB_NAME`, etc.) sont injectées lors du déploiement via le script d'initialisation de l'instance EC2.

### API REST

L'application expose les endpoints REST suivants :

| Méthode | URL                   | Description                           |
|---------|------------------------|---------------------------------------|
| GET     | /api/media             | Liste tous les médias                 |
| GET     | /api/media/{id}        | Récupère un média par son ID          |
| POST    | /api/media             | Crée un nouveau média                 |
| PUT     | /api/media/{id}        | Met à jour un média existant          |
| DELETE  | /api/media/{id}        | Supprime un média                     |
| POST    | /api/media/upload      | Upload un fichier média vers S3       |
| GET     | /api/media/download/{id}| Télécharge un fichier média depuis S3 |

### Accès à la base de données

L'accès à la base de données est géré via Spring Data JPA. Les entités principales sont :

- **Media** : Représente un média (image, vidéo, etc.)
- **User** : Représente un utilisateur de l'application
- **Category** : Représente une catégorie de médias

### Accès au stockage S3

L'accès au bucket S3 est géré via le SDK AWS pour Java. Les fichiers médias sont stockés dans le bucket S3 et les métadonnées sont stockées dans la base de données MySQL.

```java
@Service
public class S3Service {

    @Value("${aws.s3.bucket}")
    private String bucketName;

    private final AmazonS3 s3Client;

    public S3Service() {
        this.s3Client = AmazonS3ClientBuilder.standard()
                .withRegion(Regions.EU_WEST_3)
                .build();
    }

    public String uploadFile(MultipartFile file, String key) {
        try {
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.setContentLength(file.getSize());
            metadata.setContentType(file.getContentType());

            s3Client.putObject(bucketName, key, file.getInputStream(), metadata);

            return s3Client.getUrl(bucketName, key).toString();
        } catch (IOException e) {
            throw new RuntimeException("Failed to upload file to S3", e);
        }
    }

    public S3Object downloadFile(String key) {
        return s3Client.getObject(bucketName, key);
    }

    public void deleteFile(String key) {
        s3Client.deleteObject(bucketName, key);
    }
}
```

## Application Frontend (React)

L'application frontend est développée avec React Native Web, permettant une expérience utilisateur fluide et réactive. Elle communique avec le backend via des appels API REST.

### Structure du projet frontend

```
app-react/
├── src/
│   ├── components/           # Composants React réutilisables
│   ├── screens/              # Écrans de l'application
│   ├── services/             # Services (API, authentification, etc.)
│   ├── utils/                # Utilitaires
│   ├── App.js                # Composant principal
│   └── index.js              # Point d'entrée
├── public/                   # Ressources statiques
├── package.json              # Configuration npm
└── README.md                 # Documentation spécifique
```

### Configuration frontend

La configuration de l'application est définie dans les fichiers `.env` :

```
# .env.development
REACT_APP_API_URL=http://localhost:8080/api
REACT_APP_S3_BUCKET=yourmedia-dev-storage

# .env.production
REACT_APP_API_URL=http://${EC2_PUBLIC_IP}:8080/api
REACT_APP_S3_BUCKET=${S3_BUCKET_NAME}
```

Les variables d'environnement (`EC2_PUBLIC_IP`, `S3_BUCKET_NAME`) sont injectées lors du déploiement via Docker.

### Composants principaux

L'application est composée des composants principaux suivants :

- **MediaList** : Affiche la liste des médias
- **MediaDetail** : Affiche les détails d'un média
- **MediaUpload** : Permet d'uploader un nouveau média
- **MediaEdit** : Permet de modifier un média existant
- **Login** : Gère l'authentification des utilisateurs
- **Register** : Permet de créer un nouveau compte utilisateur

### Intégration avec l'API

L'intégration avec l'API backend est gérée via le service `ApiService` :

```javascript
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL;

const ApiService = {
  // Media
  getAllMedia: () => axios.get(`${API_URL}/media`),
  getMediaById: (id) => axios.get(`${API_URL}/media/${id}`),
  createMedia: (media) => axios.post(`${API_URL}/media`, media),
  updateMedia: (id, media) => axios.put(`${API_URL}/media/${id}`, media),
  deleteMedia: (id) => axios.delete(`${API_URL}/media/${id}`),
  uploadMedia: (file, metadata) => {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('metadata', JSON.stringify(metadata));
    return axios.post(`${API_URL}/media/upload`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    });
  },

  // Authentication
  login: (credentials) => axios.post(`${API_URL}/auth/login`, credentials),
  register: (user) => axios.post(`${API_URL}/auth/register`, user),
  logout: () => axios.post(`${API_URL}/auth/logout`),
};

export default ApiService;
```

## Déploiement des applications

### Déploiement du backend

Le déploiement du backend est géré via GitHub Actions. Le workflow de déploiement effectue les étapes suivantes :

1. Compilation du code Java avec Maven
2. Création d'un fichier WAR
3. Upload du WAR vers le bucket S3
4. Déploiement du WAR sur l'instance EC2 via SSH

```yaml
name: Deploy Backend

on:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Set up JDK 11
        uses: actions/setup-java@v2
        with:
          java-version: '11'
          distribution: 'adopt'

      - name: Build with Maven
        run: |
          cd app-java
          mvn clean package

      - name: Upload WAR to S3
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3

      - name: Copy WAR to S3
        run: |
          aws s3 cp app-java/target/yourmedia.war s3://${{ secrets.S3_BUCKET_NAME }}/builds/backend/yourmedia.war

      - name: Deploy to EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_PUBLIC_IP }}
          username: ec2-user
          key: ${{ secrets.EC2_SSH_PRIVATE_KEY }}
          script: |
            sudo aws s3 cp s3://${{ secrets.S3_BUCKET_NAME }}/builds/backend/yourmedia.war /var/lib/tomcat/webapps/ROOT.war
            sudo systemctl restart tomcat
```

### Déploiement du frontend

Le déploiement du frontend est géré via GitHub Actions. Le workflow de déploiement effectue les étapes suivantes :

1. Construction de l'image Docker pour l'application React Native
2. Push de l'image vers Docker Hub
3. Déploiement de l'image sur l'instance EC2 via SSH

```yaml
name: Deploy Frontend

on:
  push:
    branches: [ main ]
    paths:
      - 'app-react/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'

      - name: Build Docker image
        run: |
          cd app-react
          docker build -t ${{ secrets.DOCKERHUB_USERNAME }}/yourmedia-ecf:mobile-latest .

      - name: Login to Docker Hub
        uses: docker/login-action@v1
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Push Docker image
        run: |
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/yourmedia-ecf:mobile-latest

      - name: Deploy to EC2
        run: |
          ./scripts/deploy-containers.sh app
```

## Corrections et améliorations

### Corrections récentes

#### Workflows GitHub Actions

1. **Correction de la numérotation des workflows** : Renommage des fichiers de workflow pour avoir une numérotation cohérente et logique.
2. **Mise à jour des références aux workflows** : Mise à jour de toutes les références aux workflows dans la documentation.
3. **Correction des paramètres d'entrée** : Simplification des paramètres d'entrée du workflow d'infrastructure.
4. **Automatisation du stockage des outputs Terraform** : Stockage automatique des outputs Terraform dans les secrets GitHub.
5. **Correction du problème de cache des dépendances** : Résolution du problème de cache des dépendances dans le workflow frontend.

#### Backend (Java)

1. **Vulnérabilité MySQL Connector/J** : Mise à jour de la version du connecteur MySQL pour corriger une vulnérabilité de sécurité.
2. **Problème de déploiement du WAR** : Correction du chemin de déploiement du WAR sur l'instance EC2.
3. **Problème de CORS** : Ajout de la configuration CORS pour permettre les requêtes depuis le frontend.
4. **Problème d'authentification** : Correction du mécanisme d'authentification pour gérer correctement les tokens JWT.
5. **Configuration de l'utilisateur SSH** : Utilisation de l'utilisateur `ec2-user` au lieu de `ubuntu` pour la connexion SSH.

#### Frontend (React Native Web)

1. **Migration d'Amplify vers Docker** : Remplacement d'AWS Amplify par des conteneurs Docker pour le déploiement du frontend.
2. **Correction du problème de dépendances** : Génération du fichier package-lock.json et désactivation du cache dans le workflow GitHub Actions.
3. **Ajout de la dépendance manquante** : Installation de la dépendance `@expo/metro-runtime` pour la compilation web de l'application Expo.

#### Infrastructure

1. **Correction des erreurs de déploiement Terraform** : Résolution des problèmes d'incompatibilité entre MySQL 8.0 et l'instance db.t2.micro.
2. **Correction des erreurs de validation Terraform** : Correction des références de variables et de ressources dans les modules Terraform.
3. **Correction du fichier main.tf du module RDS MySQL** : Résolution des problèmes d'encodage et utilisation du secret DB_NAME.
4. **Configuration de Grafana/Prometheus dans des conteneurs Docker** : Déploiement de Grafana et Prometheus dans des conteneurs Docker sur une instance EC2 dédiée au monitoring.
5. **Création d'un VPC et de sous-réseaux dédiés** : Mise en place d'un VPC dédié au projet avec des sous-réseaux dans une seule zone de disponibilité.

### Améliorations planifiées

1. **Tests automatisés** : Ajout de tests unitaires et d'intégration pour le backend et le frontend.
2. **Documentation API** : Ajout de Swagger pour documenter l'API REST.
3. **Monitoring** : Configuration de dashboards Grafana pour le monitoring des applications.
4. **CI/CD** : Amélioration des workflows GitHub Actions pour automatiser davantage le déploiement.
5. **Sécurité** : Mise en place de HTTPS pour sécuriser les communications.
6. **Optimisation des coûts** : Réduction des coûts en optimisant l'utilisation des ressources AWS.
