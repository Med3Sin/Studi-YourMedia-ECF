# Variables d'Environnement

## Vue d'ensemble

Ce document décrit toutes les variables d'environnement utilisées dans le projet YourMedia. Ces variables sont essentielles pour la configuration et le fonctionnement des différents composants du système.

## Structure des Fichiers

```
.
├── .env.example           # Template des variables d'environnement
├── app-java/.env         # Variables pour l'application Java
├── app-react/.env        # Variables pour l'application React
└── infrastructure/       # Variables Terraform
    ├── variables.tf
    └── terraform.tfvars
```

## Variables Globales

### AWS Configuration
```bash
AWS_REGION=eu-west-3
AWS_PROFILE=yourmedia
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
```

### Base de Données
```bash
DB_HOST=yourmedia-db.xxxxx.region.rds.amazonaws.com
DB_PORT=3306
DB_NAME=yourmedia
DB_USER=admin
DB_PASSWORD=your_secure_password
```

### Monitoring
```bash
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
LOKI_PORT=3100
```

## Variables Java

### Application
```bash
SPRING_PROFILES_ACTIVE=prod
SERVER_PORT=8080
JAVA_OPTS=-Xmx512m -Xms256m
```

### Base de Données
```bash
SPRING_DATASOURCE_URL=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}
SPRING_DATASOURCE_USERNAME=${DB_USER}
SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
```

### JWT
```bash
JWT_SECRET=your_jwt_secret
JWT_EXPIRATION=86400000
```

## Variables React

### API
```bash
REACT_APP_API_URL=https://api.yourmedia.com
REACT_APP_API_VERSION=v1
```

### Authentication
```bash
REACT_APP_AUTH_DOMAIN=yourmedia.auth0.com
REACT_APP_AUTH_CLIENT_ID=your_client_id
REACT_APP_AUTH_AUDIENCE=your_audience
```

## Variables Terraform

### Infrastructure
```hcl
project_name     = "yourmedia"
environment      = "prod"
region           = "eu-west-3"
vpc_cidr         = "10.0.0.0/16"
```

### EC2
```hcl
instance_type    = "t3.micro"
ami_id           = "ami-xxxxx"
key_name         = "yourmedia-key"
```

### RDS
```hcl
db_instance_type = "db.t3.micro"
db_allocated_storage = 20
db_engine_version   = "8.0.28"
```

## Sécurité

### Bonnes Pratiques
1. Ne jamais commiter les fichiers `.env` dans Git
2. Utiliser des secrets managers (AWS Secrets Manager)
3. Rotation régulière des clés et mots de passe
4. Utiliser des variables d'environnement pour les secrets

### Gestion des Secrets
```bash
# AWS Secrets Manager
aws secretsmanager create-secret \
    --name yourmedia/prod/db-credentials \
    --secret-string '{"username":"admin","password":"your_secure_password"}'
```

## Déploiement

### Local
1. Copier `.env.example` vers `.env`
2. Remplir les variables avec les valeurs appropriées
3. Vérifier les permissions du fichier

### Production
1. Utiliser AWS Systems Manager Parameter Store
2. Injecter les variables via CI/CD
3. Vérifier les variables avant le déploiement

## Dépannage

### Problèmes Courants
1. Variables manquantes
2. Valeurs incorrectes
3. Problèmes de permissions
4. Conflits de variables

### Solutions
1. Vérifier les logs d'application
2. Utiliser les commandes de debug
3. Vérifier les fichiers de configuration
4. Consulter la documentation

## Maintenance

### Mise à Jour
1. Documenter les changements
2. Tester les nouvelles variables
3. Mettre à jour les templates
4. Vérifier la compatibilité

### Nettoyage
1. Supprimer les variables inutilisées
2. Archiver les anciennes configurations
3. Mettre à jour la documentation
