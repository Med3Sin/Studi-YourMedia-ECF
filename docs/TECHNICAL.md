# 🛠 Documentation Technique - YourMedia

Ce document détaille les aspects techniques du projet YourMedia, incluant l'architecture des applications, les configurations et les bonnes pratiques.

## 📋 Table des matières

1. [Backend (Java)](#backend-java)
2. [Frontend (React Native/Expo)](#frontend-react-native-expo)
3. [Infrastructure](#infrastructure)
4. [Monitoring](#monitoring)
5. [Sécurité](#sécurité)
6. [Tests](#tests)
7. [Déploiement](#déploiement)

## 💻 Backend (Java)

### Structure du projet

```
app-java/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── yourmedia/
│   │   │           └── backend/
│   │   │               ├── controller/
│   │   │               └── Application.java
│   │   └── resources/
│   └── test/
└── pom.xml
```

### Dépendances principales

| Dépendance | Version | Description |
|------------|---------|-------------|
| Spring Boot | 3.2.3 | Framework principal |
| Spring Web | 3.2.3 | Support REST |
| Spring Actuator | 3.2.3 | Monitoring |
| Micrometer | 1.12.3 | Métriques Prometheus |

### Configuration Maven

```xml
<properties>
    <java.version>17</java.version>
    <spring.boot.version>3.2.3</spring.boot.version>
</properties>
```

### Points d'entrée API

| Endpoint | Méthode | Description | Authentification |
|----------|---------|-------------|------------------|
| `/api/health` | GET | Health check | Non |
| `/api/metrics` | GET | Métriques Prometheus | Non |
| `/api/media` | GET | Liste des médias | Oui |
| `/api/media/{id}` | GET | Détails média | Oui |
| `/api/media` | POST | Upload média | Oui |

### Configuration Spring Boot

```yaml
server:
  port: 8080
  tomcat:
    max-threads: 200
    min-spare-threads: 10

spring:
  application:
    name: yourmedia-backend
  servlet:
    multipart:
      max-file-size: 100MB
      max-request-size: 100MB

management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

## 🎨 Frontend (React Native/Expo)

### Structure du projet

```
app-react/
├── src/
│   ├── components/
│   ├── screens/
│   ├── services/
│   ├── utils/
│   └── App.js
├── public/
├── app.json
├── package.json
└── Dockerfile
```

### Dépendances principales

| Dépendance | Version | Description |
|------------|---------|-------------|
| Expo | 52.0.44 | Framework React Native |
| React | 18.2.0 | Framework UI |
| React Native | 0.73.6 | Framework mobile |
| React Native Web | 0.19.6 | Support web |

### Configuration Expo

```json
{
  "expo": {
    "name": "YourMedia",
    "slug": "yourmedia",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "assetBundlePatterns": [
      "**/*"
    ],
    "ios": {
      "supportsTablet": true
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "platforms": ["ios", "android", "web"]
  }
}
```

### Configuration des plateformes

| Plateforme | Configuration | Description |
|------------|---------------|-------------|
| iOS | `supportsTablet: true` | Support des tablettes |
| Android | `adaptiveIcon` | Icône adaptative |
| Web | `favicon` | Icône du navigateur |

### Assets

- `icon.png`: Icône principale (1024x1024)
- `splash.png`: Écran de démarrage (2048x2048)
- `adaptive-icon.png`: Icône Android (1024x1024)
- `favicon.png`: Icône web (32x32)

### Composants principaux

| Composant | Description | Props |
|-----------|-------------|-------|
| `MediaList` | Liste des médias | `items`, `onSelect` |
| `MediaPlayer` | Lecteur vidéo | `source`, `controls` |
| `UploadForm` | Formulaire upload | `onUpload` |
| `AuthForm` | Authentification | `onLogin` |

### Configuration Docker

```dockerfile
FROM node:16-alpine

# Installer les dépendances nécessaires
RUN apk add --no-cache bash curl

# Définir le répertoire de travail
WORKDIR /app

# Installer un serveur web léger
RUN npm install -g serve

# Créer un répertoire pour l'application
RUN mkdir -p /app/build

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Variables d'environnement
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV NODE_OPTIONS="--max-old-space-size=256"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Démarrer le serveur
CMD ["serve", "-s", "build", "-l", "8080"]
```

### Sécurité Docker

- Utilisation d'un utilisateur non-root
- Health check pour la surveillance
- Limitation de la mémoire
- Serveur web léger (serve)

## 🏗 Infrastructure

### Terraform Modules

| Module | Description | Variables |
|--------|-------------|-----------|
| `network` | VPC et subnets | `vpc_cidr`, `azs` |
| `ec2-java-tomcat` | Instance backend | `instance_type`, `ami` |
| `rds-mysql` | Base de données | `instance_class`, `storage` |
| `s3-storage` | Stockage média | `bucket_name` |
| `monitoring` | Prometheus/Grafana | `retention_days` |

### Configuration EC2

```hcl
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }
  
  user_data = templatefile("${path.module}/templates/user-data.sh", {
    java_version = "17"
    tomcat_version = "9.0"
  })
}
```

## 📊 Monitoring

### Prometheus

- **Port**: 9090
- **Rétention**: 15 jours
- **Scraping**: 15s
- **Targets**:
  - Node Exporter
  - MySQL Exporter
  - Application metrics

### Grafana

- **Port**: 3000
- **Dashboards**:
  - System Overview
  - Application Metrics
  - Database Performance
  - Storage Usage

### Métriques clés

| Métrique | Description | Seuil d'alerte |
|----------|-------------|----------------|
| `http_server_requests_seconds` | Latence HTTP | > 1s |
| `jvm_memory_used_bytes` | Mémoire JVM | > 80% |
| `tomcat_threads_current` | Threads Tomcat | > 150 |
| `mysql_connections` | Connexions DB | > 80% |

## 🔒 Sécurité

### IAM

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
```

### Security Groups

```hcl
resource "aws_security_group" "app_sg" {
  name = "${var.project_name}-${var.environment}-app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## 🧪 Tests

### Backend

```java
@SpringBootTest
@AutoConfigureMockMvc
public class MediaControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @Test
    public void testGetMediaList() throws Exception {
        mockMvc.perform(get("/api/media"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$", hasSize(greaterThan(0))));
    }
}
```

### Frontend

```javascript
describe('MediaList', () => {
  it('renders media items', () => {
    const items = [
      { id: 1, title: 'Video 1' },
      { id: 2, title: 'Video 2' }
    ];
    
    render(<MediaList items={items} />);
    expect(screen.getByText('Video 1')).toBeInTheDocument();
  });
});
```

## 🚀 Déploiement

### GitHub Actions

```yaml
name: Deploy Backend

on:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
      - name: Build with Maven
        run: mvn clean package
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: backend-war
          path: app-java/target/*.war
```

### Scripts d'automatisation

- `install-all.sh`: Installation complète
- `setup-monitoring-agents.sh`: Configuration des agents
- `deploy.sh`: Déploiement des applications

## 📚 Ressources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [React Documentation](https://reactjs.org/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Documentation](https://docs.aws.amazon.com)
- [Prometheus Documentation](https://prometheus.io/docs)
- [Grafana Documentation](https://grafana.com/docs) 