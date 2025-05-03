# Guide Terraform pour YourMedia

Ce document centralise toutes les informations relatives à Terraform dans le projet YourMedia.

## 1. Vue d'ensemble

Terraform est utilisé dans ce projet pour provisionner et gérer l'infrastructure AWS de YourMedia. L'infrastructure est définie comme code (IaC) dans les fichiers Terraform situés dans le dossier `infrastructure/`.

## 2. Structure des fichiers Terraform

```
infrastructure/
├── main.tf           # Configuration principale
├── variables.tf      # Définition des variables
├── outputs.tf        # Définition des sorties
├── providers.tf      # Configuration des fournisseurs
└── modules/          # Modules réutilisables
    ├── ec2-java-tomcat/  # Module pour les instances EC2 Java/Tomcat
    ├── ec2-monitoring/   # Module pour les instances EC2 de monitoring
    ├── network/          # Module pour les ressources réseau
    ├── rds-mysql/        # Module pour la base de données RDS MySQL
    ├── s3/               # Module pour les buckets S3
    └── security/         # Module pour les groupes de sécurité
```

## 3. Variables Terraform standardisées

### 3.1. Variables AWS

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `aws_region` | Région AWS | `eu-west-3` (Paris) |
| `aws_access_key` | Clé d'accès AWS | - |
| `aws_secret_key` | Clé secrète AWS | - |

### 3.2. Variables RDS

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `db_username` | Nom d'utilisateur RDS | `yourmedia` |
| `db_password` | Mot de passe RDS | - |
| `db_name` | Nom de la base de données | `yourmedia` |
| `db_instance_class` | Type d'instance RDS | `db.t3.micro` |

### 3.3. Variables Docker

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `dockerhub_username` | Nom d'utilisateur Docker Hub | - |
| `dockerhub_token` | Token Docker Hub | - |
| `dockerhub_repo` | Nom du dépôt Docker Hub | `yourmedia-ecf` |

### 3.4. Variables Grafana

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `grafana_admin_password` | Mot de passe administrateur Grafana | - |

## 4. Commandes Terraform courantes

### 4.1. Initialisation

```bash
cd infrastructure
terraform init
```

### 4.2. Planification

```bash
terraform plan \
  -var="aws_access_key=$AWS_ACCESS_KEY_ID" \
  -var="aws_secret_key=$AWS_SECRET_ACCESS_KEY" \
  -var="db_username=$RDS_USERNAME" \
  -var="db_password=$RDS_PASSWORD" \
  -var="dockerhub_username=$DOCKERHUB_USERNAME" \
  -var="dockerhub_token=$DOCKERHUB_TOKEN" \
  -var="dockerhub_repo=$DOCKERHUB_REPO" \
  -var="grafana_admin_password=$GF_SECURITY_ADMIN_PASSWORD"
```

### 4.3. Application

```bash
terraform apply \
  -var="aws_access_key=$AWS_ACCESS_KEY_ID" \
  -var="aws_secret_key=$AWS_SECRET_ACCESS_KEY" \
  -var="db_username=$RDS_USERNAME" \
  -var="db_password=$RDS_PASSWORD" \
  -var="dockerhub_username=$DOCKERHUB_USERNAME" \
  -var="dockerhub_token=$DOCKERHUB_TOKEN" \
  -var="dockerhub_repo=$DOCKERHUB_REPO" \
  -var="grafana_admin_password=$GF_SECURITY_ADMIN_PASSWORD"
```

### 4.4. Destruction

```bash
terraform destroy \
  -var="aws_access_key=$AWS_ACCESS_KEY_ID" \
  -var="aws_secret_key=$AWS_SECRET_ACCESS_KEY" \
  -var="db_username=$RDS_USERNAME" \
  -var="db_password=$RDS_PASSWORD" \
  -var="dockerhub_username=$DOCKERHUB_USERNAME" \
  -var="dockerhub_token=$DOCKERHUB_TOKEN" \
  -var="dockerhub_repo=$DOCKERHUB_REPO" \
  -var="grafana_admin_password=$GF_SECURITY_ADMIN_PASSWORD"
```

## 5. Terraform Cloud

### 5.1. Configuration

Le projet utilise Terraform Cloud pour stocker l'état Terraform (tfstate). Voici comment il est configuré :

```hcl
terraform {
  backend "remote" {
    organization = "yourmedia"
    workspaces {
      name = "yourmedia-dev"
    }
  }
}
```

### 5.2. Variables Terraform Cloud

Les variables suivantes doivent être configurées dans Terraform Cloud :

| Variable | Type | Sensible | Description |
|----------|------|----------|-------------|
| `aws_access_key` | Terraform | Oui | Clé d'accès AWS |
| `aws_secret_key` | Terraform | Oui | Clé secrète AWS |
| `db_username` | Terraform | Oui | Nom d'utilisateur RDS |
| `db_password` | Terraform | Oui | Mot de passe RDS |
| `dockerhub_username` | Terraform | Oui | Nom d'utilisateur Docker Hub |
| `dockerhub_token` | Terraform | Oui | Token Docker Hub |
| `dockerhub_repo` | Terraform | Non | Nom du dépôt Docker Hub |
| `grafana_admin_password` | Terraform | Oui | Mot de passe administrateur Grafana |

### 5.3. Synchronisation des secrets

Le projet inclut un script pour synchroniser les secrets GitHub avec Terraform Cloud :

```bash
./scripts/utils/sync-github-secrets-to-terraform.sh
```

## 6. Bonnes pratiques

### 6.1. Sécurité

- Ne stockez jamais de secrets en clair dans les fichiers Terraform
- Utilisez des variables pour tous les secrets
- Utilisez Terraform Cloud ou un autre backend distant pour stocker l'état Terraform
- Limitez les permissions des utilisateurs Terraform

### 6.2. Organisation du code

- Utilisez des modules pour organiser le code
- Utilisez des variables pour tous les paramètres configurables
- Documentez toutes les variables et sorties
- Utilisez des noms descriptifs pour les ressources

### 6.3. Optimisation pour le free tier AWS

- Utilisez des types d'instances éligibles au free tier (t2.micro, db.t3.micro)
- Limitez la taille des volumes EBS (8-10 GB)
- Configurez des politiques d'arrêt automatique pour les instances EC2
- Utilisez des règles de cycle de vie pour les buckets S3

## 7. Dépannage

### 7.1. Problèmes courants

- **Erreur "No valid credential sources found"** : Vérifiez les variables AWS_ACCESS_KEY_ID et AWS_SECRET_ACCESS_KEY
- **Erreur "Error acquiring the state lock"** : Un autre processus Terraform est en cours d'exécution
- **Erreur "Error creating DB Instance"** : Vérifiez les paramètres RDS et les groupes de sécurité

### 7.2. Commandes utiles

```bash
# Voir l'état Terraform
terraform state list

# Voir les détails d'une ressource
terraform state show aws_instance.example

# Forcer le déverrouillage de l'état
terraform force-unlock LOCK_ID

# Importer une ressource existante
terraform import aws_instance.example i-abcd1234
```
