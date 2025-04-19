# Opérations - YourMédia

Ce document centralise toute la documentation relative aux opérations du projet YourMédia, incluant le déploiement, le monitoring, la maintenance et la sécurité.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [CI/CD avec GitHub Actions](#cicd-avec-github-actions)
   - [Workflows](#workflows)
   - [Secrets GitHub](#secrets-github)
   - [Terraform Cloud](#terraform-cloud)
3. [Monitoring](#monitoring)
   - [Architecture de monitoring](#architecture-de-monitoring)
   - [Prometheus](#prometheus)
   - [Grafana](#grafana)
   - [CloudWatch](#cloudwatch)
   - [Alertes](#alertes)
4. [Maintenance](#maintenance)
   - [Backups](#backups)
   - [Mises à jour](#mises-à-jour)
   - [Scaling](#scaling)
5. [Sécurité](#sécurité)
   - [IAM et gestion des accès](#iam-et-gestion-des-accès)
   - [Sécurité réseau](#sécurité-réseau)
   - [Gestion des secrets](#gestion-des-secrets)
   - [Chiffrement](#chiffrement)
6. [Troubleshooting](#troubleshooting)
   - [Problèmes courants](#problèmes-courants)
   - [Logs](#logs)
   - [Diagnostics](#diagnostics)

## Vue d'ensemble

Les opérations du projet YourMédia sont entièrement automatisées via GitHub Actions et Terraform. Le monitoring est assuré par Prometheus et Grafana déployés sur une instance EC2 dédiée.

## CI/CD avec GitHub Actions

### Workflows

Le projet utilise plusieurs workflows GitHub Actions pour automatiser le déploiement et la maintenance de l'infrastructure et des applications.

#### 1. Infrastructure Deployment/Destruction

Fichier: `.github/workflows/1-infra-deploy-destroy.yml`

Ce workflow gère le déploiement et la destruction de l'infrastructure AWS via Terraform.

```yaml
name: 1-Infrastructure-Deploy-Destroy

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Action to perform (deploy or destroy)'
        required: true
        default: 'deploy'
        type: choice
        options:
          - deploy
          - destroy

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}

      - name: Terraform Init
        run: |
          cd infrastructure
          terraform init

      - name: Terraform Plan
        run: |
          cd infrastructure
          terraform plan -var="db_username=${{ secrets.DB_USERNAME }}" -var="db_password=${{ secrets.DB_PASSWORD }}" -var="ssh_public_key=${{ secrets.EC2_SSH_PUBLIC_KEY }}" -var="key_pair_name=${{ secrets.EC2_KEY_PAIR_NAME }}"

      - name: Terraform Apply
        if: github.event.inputs.action == 'deploy'
        run: |
          cd infrastructure
          terraform apply -auto-approve -var="db_username=${{ secrets.DB_USERNAME }}" -var="db_password=${{ secrets.DB_PASSWORD }}" -var="ssh_public_key=${{ secrets.EC2_SSH_PUBLIC_KEY }}" -var="key_pair_name=${{ secrets.EC2_KEY_PAIR_NAME }}"

      - name: Terraform Destroy
        if: github.event.inputs.action == 'destroy'
        run: |
          cd infrastructure
          terraform destroy -auto-approve -var="db_username=${{ secrets.DB_USERNAME }}" -var="db_password=${{ secrets.DB_PASSWORD }}" -var="ssh_public_key=${{ secrets.EC2_SSH_PUBLIC_KEY }}" -var="key_pair_name=${{ secrets.EC2_KEY_PAIR_NAME }}"

      - name: Save Terraform Outputs as GitHub Secrets
        if: github.event.inputs.action == 'deploy'
        uses: gliech/create-github-secret-action@v1
        with:
          name: EC2_PUBLIC_IP
          value: ${{ steps.terraform_output.outputs.ec2_public_ip }}
          pa_token: ${{ secrets.GH_PAT }}
```

#### 2. Backend Deployment

Fichier: `.github/workflows/2-backend-deploy.yml`

Ce workflow gère le déploiement de l'application backend Java sur l'instance EC2.

```yaml
name: 2-Backend-Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'app-java/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 11
        uses: actions/setup-java@v2
        with:
          java-version: '11'
          distribution: 'adopt'

      - name: Build with Maven
        run: |
          cd app-java
          mvn clean package

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3

      - name: Upload WAR to S3
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

#### 3. Frontend Deployment

Fichier: `.github/workflows/3-frontend-deploy.yml`

Ce workflow gère le déploiement de l'application frontend React sur AWS Amplify.

```yaml
name: 3-Frontend-Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'app-react/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '16'

      - name: Install dependencies
        run: |
          cd app-react
          npm install

      - name: Build
        run: |
          cd app-react
          npm run build

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-3

      - name: Upload build to S3
        run: |
          aws s3 sync app-react/build s3://${{ secrets.S3_BUCKET_NAME }}/builds/frontend/
```

### Secrets GitHub

Les secrets suivants doivent être configurés dans les paramètres du repository GitHub :

* `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` : Identifiants AWS
* `DB_USERNAME` et `DB_PASSWORD` : Identifiants pour la base de données RDS
* `EC2_SSH_PRIVATE_KEY` et `EC2_SSH_PUBLIC_KEY` : Clés SSH pour l'accès aux instances EC2
* `EC2_KEY_PAIR_NAME` : Nom de la paire de clés EC2 dans AWS
* `GH_PAT` : Personal Access Token GitHub pour les intégrations
* `TF_API_TOKEN` : Token d'API Terraform Cloud

### Terraform Cloud

Terraform Cloud est utilisé pour stocker l'état Terraform et exécuter les opérations Terraform. La configuration est la suivante :

* **Organisation** : Med3Sin
* **Workspace** : Med3Sin-CLI
* **Version Control** : GitHub
* **Execution Mode** : Remote

## Monitoring

### Architecture de monitoring

Le monitoring est assuré par Prometheus et Grafana déployés sur une instance EC2 dédiée. Cette architecture permet de collecter et visualiser les métriques de l'infrastructure et des applications.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  EC2 Java/Tomcat│     │  EC2 Monitoring │     │  RDS MySQL      │
│                 │     │                 │     │                 │
│  ┌───────────┐  │     │  ┌───────────┐  │     │                 │
│  │ Node      │◄─┼─────┼─►│Prometheus │  │     │                 │
│  │ Exporter  │  │     │  │           │  │     │                 │
│  └───────────┘  │     │  └─────┬─────┘  │     │                 │
│                 │     │        │        │     │                 │
│  ┌───────────┐  │     │  ┌─────▼─────┐  │     │                 │
│  │ JMX       │◄─┼─────┼─►│ Grafana   │  │     │                 │
│  │ Exporter  │  │     │  │           │  │     │                 │
│  └───────────┘  │     │  └───────────┘  │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Prometheus

Prometheus est déployé dans un conteneur Docker sur l'instance EC2 de monitoring. Il est configuré pour collecter les métriques des instances EC2, RDS et de l'application.

#### Configuration

La configuration de Prometheus est définie dans le fichier `prometheus.yml` :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ec2-java'
    static_configs:
      - targets: ['ec2-java-tomcat:8080']
    metrics_path: '/actuator/prometheus'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['ec2-java-tomcat:9100']

  - job_name: 'cloudwatch-exporter'
    static_configs:
      - targets: ['localhost:9106']
```

### Grafana

Grafana est déployé dans un conteneur Docker sur l'instance EC2 de monitoring. Il est configuré pour visualiser les métriques collectées par Prometheus.

#### Dashboards

Les dashboards suivants sont préconfigurés :

1. **Infrastructure Overview** : Vue d'ensemble de l'infrastructure (CPU, mémoire, disque, réseau)
2. **EC2 Java/Tomcat** : Métriques spécifiques à l'instance EC2 Java/Tomcat
3. **RDS MySQL** : Métriques spécifiques à l'instance RDS MySQL
4. **Application Java** : Métriques spécifiques à l'application Java (JVM, requêtes HTTP, etc.)
5. **S3 Storage** : Métriques spécifiques au bucket S3

#### Accès

Grafana est accessible à l'adresse suivante : `http://<MONITORING_EC2_PUBLIC_IP>:3000`

* **Utilisateur** : admin
* **Mot de passe** : admin (à changer après la première connexion)

#### Gestion des permissions

Les conteneurs Docker pour Grafana et Prometheus peuvent rencontrer des problèmes de permissions lorsqu'ils tentent d'écrire dans les volumes montés. Ces problèmes se manifestent par :

1. **Pour Prometheus** : Erreur `open /prometheus/queries.active: permission denied`
2. **Pour Grafana** : Erreur `GF_PATHS_DATA='/var/lib/grafana' is not writable`

Un script de correction des permissions (`fix_permissions.sh`) est automatiquement exécuté lors du provisionnement de l'instance EC2 de monitoring. Ce script :

1. Arrête les conteneurs existants s'ils sont en cours d'exécution
2. Nettoie les répertoires de données
3. Corrige les permissions des répertoires :
   - `/opt/monitoring/prometheus-data` : propriétaire 65534:65534 (utilisateur Prometheus)
   - `/opt/monitoring/grafana-data` : propriétaire 472:472 (utilisateur Grafana)
4. Crée un fichier `docker-compose.yml` avec les utilisateurs spécifiés
5. Redémarre les conteneurs

Si vous rencontrez toujours des problèmes, vous pouvez exécuter manuellement le script de correction des permissions :

```bash
# Se connecter à l'instance EC2
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>

# Exécuter le script de correction des permissions
sudo /opt/monitoring/fix_permissions.sh
```

### CloudWatch

CloudWatch est utilisé pour collecter les métriques AWS natives. Un exportateur CloudWatch est déployé dans un conteneur Docker sur l'instance EC2 de monitoring pour exposer ces métriques à Prometheus.

#### Métriques collectées

* **EC2** : CPU, mémoire, disque, réseau
* **RDS** : CPU, mémoire, connexions, IOPS
* **S3** : Nombre d'objets, taille du bucket
* **Amplify** : Requêtes, erreurs

### Alertes

Des alertes sont configurées dans Prometheus et Grafana pour notifier en cas de problème :

1. **CPU élevé** : Alerte si le CPU dépasse 80% pendant plus de 5 minutes
2. **Mémoire élevée** : Alerte si la mémoire dépasse 80% pendant plus de 5 minutes
3. **Disque plein** : Alerte si le disque dépasse 80% d'utilisation
4. **Erreurs HTTP** : Alerte si le taux d'erreurs HTTP dépasse 5%
5. **Temps de réponse élevé** : Alerte si le temps de réponse moyen dépasse 500ms

## Maintenance

### Backups

#### Base de données

Les backups de la base de données sont désactivés pour rester dans le Free Tier AWS. Pour un environnement de production, il est recommandé d'activer les backups automatiques.

#### S3

Le versioning est activé sur le bucket S3, ce qui permet de récupérer des versions précédentes des objets. Des règles de cycle de vie sont configurées pour nettoyer automatiquement les anciens objets.

### Mises à jour

#### Système d'exploitation

Les mises à jour du système d'exploitation sont gérées manuellement. Pour appliquer les mises à jour :

```bash
# Sur l'instance EC2 Java/Tomcat
sudo yum update -y

# Sur l'instance EC2 Monitoring
sudo yum update -y
```

#### Applications

Les mises à jour des applications sont gérées via les workflows GitHub Actions. Pour déployer une nouvelle version :

1. Pusher les modifications sur la branche `main`
2. Le workflow correspondant se déclenche automatiquement
3. La nouvelle version est déployée sur l'infrastructure

### Scaling

#### Vertical Scaling

Pour effectuer un scaling vertical (augmenter les ressources d'une instance) :

1. Modifier le type d'instance dans le fichier `infrastructure/variables.tf`
2. Exécuter le workflow d'infrastructure avec l'action `deploy`

#### Horizontal Scaling

Le projet n'est pas configuré pour le scaling horizontal. Pour un environnement de production, il est recommandé de mettre en place un Auto Scaling Group.

## Sécurité

### IAM et gestion des accès

#### Rôles IAM

Les rôles IAM suivants sont créés pour les instances EC2 :

1. **EC2 Java/Tomcat** : Accès en lecture/écriture au bucket S3, accès en lecture à CloudWatch
2. **EC2 Monitoring** : Accès en lecture à CloudWatch, accès en lecture au bucket S3

#### Utilisateurs IAM

Aucun utilisateur IAM n'est créé. Les identifiants AWS sont stockés dans les secrets GitHub.

### Sécurité réseau

#### Groupes de sécurité

Les groupes de sécurité suivants sont créés :

1. **EC2 Java/Tomcat** : Autorise SSH (22) et HTTP (8080) depuis Internet
2. **EC2 Monitoring** : Autorise SSH (22), Grafana (3000) et Prometheus (9090) depuis Internet
3. **RDS MySQL** : Autorise MySQL (3306) depuis le groupe de sécurité EC2 Java/Tomcat

#### Sous-réseaux

Les sous-réseaux suivants sont créés :

1. **Public** : Pour les instances EC2
2. **Private** : Pour l'instance RDS

### Gestion des secrets

#### Secrets GitHub

Les secrets sont stockés dans les paramètres du repository GitHub et injectés dans les workflows GitHub Actions.

#### Secrets AWS

Les secrets AWS (comme les mots de passe RDS) sont stockés dans les secrets GitHub et injectés dans Terraform lors du déploiement.

### Chiffrement

#### S3

Le chiffrement côté serveur (SSE-S3) est activé sur le bucket S3.

#### RDS

Le chiffrement est désactivé sur l'instance RDS pour rester dans le Free Tier AWS. Pour un environnement de production, il est recommandé d'activer le chiffrement.

## Troubleshooting

### Optimisations pour le Free Tier AWS

Plusieurs optimisations ont été mises en place pour rester dans les limites du Free Tier AWS :

#### 1. Optimisation des scripts user_data

Les scripts d'initialisation des instances EC2 ont été optimisés pour rester sous la limite de 16 Ko imposée par AWS :

- **Approche bootstrap** : Un script minimal est utilisé dans le user_data qui télécharge et exécute un script plus complet depuis S3
- **Stockage des fichiers de configuration dans S3** : Les fichiers de configuration volumineux sont stockés dans S3 et téléchargés lors de l'initialisation
- **Substitution de variables** : Les variables sont substituées dans les scripts après leur téléchargement depuis S3

#### 2. Configuration du cycle de vie S3

La configuration du cycle de vie du bucket S3 a été optimisée pour éviter des coûts inutiles :

- **Dépendances explicites** : Des dépendances explicites ont été ajoutées pour s'assurer que le bucket est créé avant la configuration du cycle de vie
- **Règles de nettoyage automatique** : Des règles de cycle de vie sont configurées pour nettoyer automatiquement les anciens objets

#### 3. Autres optimisations Free Tier

- **Instances t2.micro/t3.micro** : Utilisation d'instances éligibles au Free Tier
- **RDS Single-AZ** : Configuration mono-AZ pour RDS
- **Placement des ressources** : Toutes les ressources qui communiquent fréquemment sont placées dans la même zone de disponibilité
- **Conteneurs Docker sur EC2** : Alternative économique à ECS Fargate

### Problèmes courants

#### 1. Échec du déploiement de l'infrastructure

**Symptômes** : Le workflow d'infrastructure échoue avec une erreur Terraform.

**Solutions** :
1. Vérifier les logs du workflow pour identifier l'erreur
2. Vérifier que les secrets GitHub sont correctement configurés
3. Vérifier que le token Terraform Cloud est valide
4. Vérifier que les identifiants AWS sont valides et ont les permissions nécessaires

#### 5. Problèmes avec les variables dans les templates Terraform

**Symptômes** : Erreur lors de la validation Terraform indiquant qu'une variable référencée dans un template n'existe pas dans la map de variables.

```
Error: Invalid function argument

Invalid value for "vars" parameter: vars map does not contain key "ec2_java_tomcat_ip", referenced at modules/s3/../ec2-monitoring/scripts/setup.sh.tpl:27,14-32.
```

**Solutions** :

1. **Ajouter la variable manquante** :
   - Identifier la variable manquante dans le template
   - Ajouter cette variable à la map de variables passée à la fonction `templatefile()`
   - S'assurer que toutes les variables utilisées dans le template sont définies

2. **Utiliser des placeholders** :
   - Pour les variables qui ne sont pas disponibles dans le module courant, utiliser des placeholders
   - Remplacer ces placeholders par les valeurs réelles dans le script `user_data`

3. **Utiliser des guillemets simples** :
   - Dans les commandes `sed`, utiliser des guillemets simples pour éviter l'interprétation des variables shell
   - Exemple : `sed -i 's/\${variable}/${valeur}/g' fichier.txt`

#### 6. Problèmes avec les profils IAM persistants

**Symptômes** : Lors de l'exécution de `terraform destroy`, certaines ressources IAM, notamment les profils d'instance IAM, peuvent ne pas être correctement supprimées. Cela provoque des erreurs lors des déploiements ultérieurs :

```
Error: creating IAM Instance Profile (yourmedia-dev-ec2-profile): operation error IAM: CreateInstanceProfile, https response error StatusCode: 409, RequestID: 29837bb2-e2df-4606-9580-375b7711a933, EntityAlreadyExists: Instance Profile yourmedia-dev-ec2-profile already exists.
```

**Solutions** :

1. **Configuration des ressources IAM dans Terraform** :
   - Ajout de `force_detach_policies = true` aux rôles IAM pour forcer le détachement des politiques lors de la suppression
   - Ajout de `lifecycle { create_before_destroy = true }` aux rôles et profils IAM pour créer de nouvelles ressources avant de supprimer les anciennes

2. **Nettoyage automatique dans le workflow GitHub Actions** :
   - Le workflow GitHub Actions `1-infra-deploy-destroy.yml` inclut une étape de nettoyage qui s'exécute après `terraform destroy` pour supprimer manuellement les profils IAM persistants

3. **Nettoyage manuel** :
   ```bash
   # Détacher le rôle du profil
   aws iam remove-role-from-instance-profile --instance-profile-name yourmedia-dev-ec2-profile --role-name yourmedia-dev-ec2-role-v2

   # Supprimer le profil
   aws iam delete-instance-profile --instance-profile-name yourmedia-dev-ec2-profile
   ```

#### 2. Échec du déploiement du backend

**Symptômes** : Le workflow de déploiement du backend échoue.

**Solutions** :
1. Vérifier les logs du workflow pour identifier l'erreur
2. Vérifier que l'instance EC2 est accessible via SSH
3. Vérifier que le bucket S3 est accessible
4. Vérifier que Tomcat est correctement configuré sur l'instance EC2

#### 3. Échec du déploiement du frontend

**Symptômes** : Le workflow de déploiement du frontend échoue.

**Solutions** :
1. Vérifier les logs du workflow pour identifier l'erreur
2. Vérifier que le bucket S3 est accessible
3. Vérifier que Amplify est correctement configuré

#### 4. Problèmes de connexion à la base de données

**Symptômes** : L'application ne peut pas se connecter à la base de données.

**Solutions** :
1. Vérifier que l'instance RDS est en cours d'exécution
2. Vérifier que le groupe de sécurité RDS autorise les connexions depuis l'instance EC2
3. Vérifier que les identifiants de la base de données sont corrects
4. Vérifier que la base de données existe

### Logs

#### EC2 Java/Tomcat

Les logs de l'application sont disponibles dans le répertoire `/var/log/tomcat` sur l'instance EC2 Java/Tomcat.

```bash
# Afficher les logs de Tomcat
sudo tail -f /var/log/tomcat/catalina.out
```

#### EC2 Monitoring

Les logs de Prometheus et Grafana sont disponibles dans les conteneurs Docker sur l'instance EC2 Monitoring.

```bash
# Afficher les logs de Prometheus
sudo docker logs prometheus

# Afficher les logs de Grafana
sudo docker logs grafana
```

#### RDS

Les logs de RDS sont disponibles dans la console AWS RDS ou via CloudWatch Logs.

### Diagnostics

#### Vérifier l'état de l'instance EC2

```bash
# Vérifier l'état de l'instance EC2
aws ec2 describe-instance-status --instance-id <INSTANCE_ID>
```

#### Vérifier l'état de l'instance RDS

```bash
# Vérifier l'état de l'instance RDS
aws rds describe-db-instances --db-instance-identifier <DB_INSTANCE_ID>
```

#### Vérifier l'état du bucket S3

```bash
# Vérifier l'état du bucket S3
aws s3 ls s3://<BUCKET_NAME>
```

#### Vérifier l'état de Tomcat

```bash
# Vérifier l'état de Tomcat
sudo systemctl status tomcat
```

#### Vérifier l'état des conteneurs Docker

```bash
# Vérifier l'état des conteneurs Docker
sudo docker ps
```
