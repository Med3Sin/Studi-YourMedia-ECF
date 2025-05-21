# Workflows GitHub Actions

## Vue d'ensemble

Ce document décrit les workflows GitHub Actions utilisés dans le projet YourMedia pour l'automatisation des processus de développement, de test et de déploiement.

## Structure des Workflows

```
.github/
└── workflows/
    ├── 1-infra-deploy-destroy.yml    # Déploiement de l'infrastructure
    ├── 2-java-app-deploy.yml         # Déploiement de l'application Java
    ├── 3-react-app-deploy.yml        # Déploiement de l'application React
    └── 4-monitoring-deploy.yml       # Déploiement du monitoring
```

## Workflow d'Infrastructure

### 1-infra-deploy-destroy.yml

Ce workflow gère le déploiement et la destruction de l'infrastructure AWS.

#### Déclencheurs
```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Action à effectuer'
        required: true
        default: 'apply'
        type: choice
        options:
          - apply
          - destroy
```

#### Étapes Principales
1. Configuration AWS
2. Initialisation Terraform
3. Validation du plan
4. Application/Destruction
5. Mise à jour des secrets

#### Secrets Requis
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `EC2_SSH_PRIVATE_KEY`
- `EC2_SSH_PUBLIC_KEY`

## Workflow d'Application Java

### 2-java-app-deploy.yml

Ce workflow gère le build et le déploiement de l'application Spring Boot.

#### Déclencheurs
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'
      - '.github/workflows/2-java-app-deploy.yml'
```

#### Étapes Principales
1. Build Maven
2. Tests unitaires
3. Build Docker
4. Push Docker Hub
5. Déploiement EC2

#### Secrets Requis
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `EC2_SSH_PRIVATE_KEY`

## Workflow d'Application React

### 3-react-app-deploy.yml

Ce workflow gère le build et le déploiement de l'application React Native.

#### Déclencheurs
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'app-react/**'
      - '.github/workflows/3-react-app-deploy.yml'
```

#### Étapes Principales
1. Installation Node.js
2. Build React
3. Tests
4. Déploiement EC2

#### Secrets Requis
- `EC2_SSH_PRIVATE_KEY`
- `REACT_APP_API_URL`

## Workflow de Monitoring

### 4-monitoring-deploy.yml

Ce workflow gère le déploiement et la configuration du système de monitoring.

#### Déclencheurs
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environnement'
        required: true
        default: 'prod'
        type: choice
        options:
          - dev
          - prod
```

#### Étapes Principales
1. Configuration AWS
2. Déploiement EC2
3. Configuration Docker
4. Configuration Prometheus
5. Configuration Grafana

#### Secrets Requis
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `GF_SECURITY_ADMIN_PASSWORD`

## Bonnes Pratiques

### 1. Sécurité
- Utiliser des secrets pour les informations sensibles
- Limiter les permissions des tokens
- Vérifier les dépendances

### 2. Performance
- Utiliser le cache pour les dépendances
- Paralléliser les jobs quand possible
- Optimiser les étapes de build

### 3. Maintenance
- Documenter les changements
- Tester les workflows localement
- Mettre à jour les dépendances

## Dépannage

### Problèmes Courants
1. Échec de l'authentification AWS
2. Timeout des jobs
3. Échec des tests
4. Problèmes de déploiement

### Solutions
1. Vérifier les secrets
2. Augmenter les timeouts
3. Examiner les logs
4. Tester localement

## Maintenance

### Mise à Jour
1. Vérifier les versions des actions
2. Tester les changements
3. Mettre à jour la documentation
4. Créer un commit descriptif

### Nettoyage
1. Supprimer les workflows inutilisés
2. Nettoyer les secrets obsolètes
3. Archiver les anciennes configurations

## Infrastructure

### 1. Déploiement Infrastructure

#### `.github/workflows/1-infra-deploy-destroy.yml`
```yaml
name: Infrastructure Deployment

on:
  push:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'infrastructure/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.0.0
      
      - name: Terraform Init
        run: |
          cd infrastructure
          terraform init
      
      - name: Terraform Plan
        run: |
          cd infrastructure
          terraform plan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd infrastructure
          terraform apply -auto-approve
```

### 2. Destruction Infrastructure

#### `.github/workflows/1-infra-deploy-destroy.yml`
```yaml
name: Infrastructure Destruction

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to destroy'
        required: true
        default: 'dev'

jobs:
  destroy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.0.0
      
      - name: Terraform Init
        run: |
          cd infrastructure
          terraform init
      
      - name: Terraform Destroy
        run: |
          cd infrastructure
          terraform destroy -auto-approve
```

## Applications

### 1. Backend Java

#### `.github/workflows/2-app-deploy.yml`
```yaml
name: Java Application Deployment

on:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'app-java/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'adopt'
      
      - name: Build with Maven
        run: |
          cd app-java
          mvn clean install
      
      - name: Run Tests
        run: |
          cd app-java
          mvn test
      
      - name: Build Docker Image
        run: |
          docker build -t yourmedia/java-app:${{ github.sha }} ./app-java
      
      - name: Push to ECR
        if: github.ref == 'refs/heads/main'
        run: |
          aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}
          docker push yourmedia/java-app:${{ github.sha }}
```

### 2. Frontend React

#### `.github/workflows/2-app-deploy.yml`
```yaml
name: React Application Deployment

on:
  push:
    branches: [ main ]
    paths:
      - 'app-react/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'app-react/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install Dependencies
        run: |
          cd app-react
          npm ci
      
      - name: Run Tests
        run: |
          cd app-react
          npm test
      
      - name: Build
        run: |
          cd app-react
          npm run build
      
      - name: Build Docker Image
        run: |
          docker build -t yourmedia/react-app:${{ github.sha }} ./app-react
      
      - name: Push to ECR
        if: github.ref == 'refs/heads/main'
        run: |
          aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}
          docker push yourmedia/react-app:${{ github.sha }}
```

## Tests

### 1. Tests Unitaires

#### `.github/workflows/3-tests.yml`
```yaml
name: Unit Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'adopt'
      
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Run Java Tests
        run: |
          cd app-java
          mvn test
      
      - name: Run React Tests
        run: |
          cd app-react
          npm test
```

### 2. Tests d'Intégration

#### `.github/workflows/3-tests.yml`
```yaml
name: Integration Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'adopt'
      
      - name: Run Integration Tests
        run: |
          cd app-java
          mvn verify
```

## Sécurité

### 1. Scan de Code

#### `.github/workflows/4-security.yml`
```yaml
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      
      - name: Run OWASP Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'YourMedia'
          path: '.'
          format: 'HTML'
```

### 2. Analyse de Code

#### `.github/workflows/4-security.yml`
```yaml
name: Code Analysis

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'adopt'
      
      - name: Run SonarQube Analysis
        uses: SonarSource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

## Documentation

### 1. Génération Documentation

#### `.github/workflows/5-docs.yml`
```yaml
name: Documentation

on:
  push:
    branches: [ main ]
    paths:
      - 'docs/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'docs/**'

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v3
        with:
          python-version: '3.9'
      
      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install mkdocs mkdocs-material
      
      - name: Build Documentation
        run: |
          mkdocs build
      
      - name: Deploy Documentation
        if: github.ref == 'refs/heads/main'
        run: |
          mkdocs gh-deploy
```

### 2. Vérification Documentation

#### `.github/workflows/5-docs.yml`
```yaml
name: Documentation Check

on:
  push:
    branches: [ main ]
    paths:
      - 'docs/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'docs/**'

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v3
        with:
          python-version: '3.9'
      
      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install mkdocs mkdocs-material
      
      - name: Check Documentation
        run: |
          mkdocs build --strict
```
