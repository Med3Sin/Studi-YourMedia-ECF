# Workflows GitHub Actions - YourMédia

Ce document décrit les workflows GitHub Actions utilisés pour automatiser le projet YourMédia.

## Table des matières

1. [Workflows de déploiement](#workflows-de-déploiement)
2. [Workflows de build](#workflows-de-build)
3. [Workflows de test](#workflows-de-test)
4. [Workflows de sécurité](#workflows-de-sécurité)
5. [Workflows de documentation](#workflows-de-documentation)

## Workflows de déploiement

### Déploiement de l'infrastructure

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
          
      - name: Terraform Init
        run: |
          cd infrastructure
          terraform init
          
      - name: Terraform Plan
        run: |
          cd infrastructure
          terraform plan -out=tfplan
          
      - name: Terraform Apply
        run: |
          cd infrastructure
          terraform apply -auto-approve tfplan
```

### Déploiement de l'application

```yaml
name: Deploy Application

on:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'
      - 'app-react/**'
  workflow_dispatch:

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup JDK
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'
          
      - name: Build with Maven
        run: |
          cd app-java
          mvn clean package
          
      - name: Upload WAR to S3
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3
        run: |
          aws s3 cp app-java/target/*.war s3://${{ secrets.S3_BUCKET }}/artifacts/
          
      - name: Deploy to EC2
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USERNAME }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/tomcat
            sudo systemctl stop tomcat
            sudo rm -rf webapps/*
            sudo aws s3 cp s3://${{ secrets.S3_BUCKET }}/artifacts/*.war webapps/ROOT.war
            sudo systemctl start tomcat
```

## Workflows de build

### Build du backend

```yaml
name: Build Backend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'app-java/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'app-java/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup JDK
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'
          
      - name: Build with Maven
        run: |
          cd app-java
          mvn clean package
          
      - name: Upload WAR
        uses: actions/upload-artifact@v3
        with:
          name: backend-war
          path: app-java/target/*.war
```

### Build du frontend

```yaml
name: Build Frontend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'app-react/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'app-react/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: |
          cd app-react
          npm ci
          
      - name: Build
        run: |
          cd app-react
          npm run build
          
      - name: Upload build
        uses: actions/upload-artifact@v3
        with:
          name: frontend-build
          path: app-react/build
```

## Workflows de test

### Tests du backend

```yaml
name: Test Backend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'app-java/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'app-java/**'

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: test
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup JDK
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'
          
      - name: Run tests
        run: |
          cd app-java
          mvn test
```

### Tests du frontend

```yaml
name: Test Frontend

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'app-react/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'app-react/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: |
          cd app-react
          npm ci
          
      - name: Run tests
        run: |
          cd app-react
          npm test
```

## Workflows de sécurité

### Analyse de sécurité

```yaml
name: Security Scan

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high
          
      - name: Run OWASP Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'YourMédia'
          path: '.'
          format: 'HTML'
          out: 'reports'
```

## Workflows de documentation

### Génération de documentation

```yaml
name: Generate Documentation

on:
  push:
    branches: [ main ]
    paths:
      - 'docs/**'
  workflow_dispatch:

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install markdownlint
        run: npm install -g markdownlint-cli
        
      - name: Lint markdown files
        run: markdownlint 'docs/**/*.md'
        
      - name: Check links
        uses: gaurav-nelson/github-action-markdown-link-check@v1
        with:
          use-quiet-mode: 'yes'
          use-verbose-mode: 'yes'
          folder-path: 'docs'
          
      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add docs/
          git commit -m "Update documentation" || exit 0
          git push
```

## Ressources

- [Documentation GitHub Actions](https://docs.github.com/en/actions)
- [Documentation Terraform](https://www.terraform.io/docs)
- [Documentation AWS](https://docs.aws.amazon.com)
- [Documentation Docker](https://docs.docker.com)
- [Documentation Maven](https://maven.apache.org/guides)
- [Documentation Node.js](https://nodejs.org/docs)
- [Documentation Snyk](https://docs.snyk.io)
- [Documentation OWASP](https://owasp.org/www-project-dependency-check)
