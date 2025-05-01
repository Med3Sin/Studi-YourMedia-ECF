# Approche de téléchargement des scripts depuis GitHub

## Introduction

Ce document explique la nouvelle approche adoptée pour le téléchargement des scripts d'initialisation et de configuration des instances EC2 dans le projet YourMedia. Au lieu de stocker les scripts dans un bucket S3, nous les téléchargeons directement depuis GitHub lors de l'initialisation des instances EC2.

## Avantages de cette approche

1. **Simplicité** : Pas besoin de gérer la copie des scripts dans le bucket S3.
2. **Cohérence** : Les scripts sont toujours à jour avec la dernière version dans le dépôt GitHub.
3. **Fiabilité** : Évite les problèmes de permissions et d'erreurs lors de la copie dans S3.
4. **Traçabilité** : Les modifications des scripts sont tracées dans l'historique Git.
5. **Économie** : Réduit les coûts de stockage et de transfert de données S3.

## Fonctionnement

### 1. Initialisation des instances EC2

Lors de l'initialisation des instances EC2, le script `user_data` télécharge le script d'initialisation directement depuis GitHub :

```bash
# Télécharger et exécuter le script d'initialisation depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script d'initialisation depuis GitHub"
sudo mkdir -p /opt/yourmedia
GITHUB_RAW_URL="https://raw.githubusercontent.com/${var.repo_owner}/${var.repo_name}/main"
sudo curl -L -o /opt/yourmedia/init-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/init-java-tomcat.sh"
sudo chmod +x /opt/yourmedia/init-java-tomcat.sh
```

### 2. Téléchargement des scripts supplémentaires

Le script d'initialisation télécharge ensuite les scripts supplémentaires nécessaires :

```bash
# Téléchargement des scripts depuis GitHub
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des scripts depuis GitHub"
GITHUB_RAW_URL="https://raw.githubusercontent.com/Med3Sin/Studi-YourMedia-ECF/main"

# Téléchargement du script de configuration
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script setup-java-tomcat.sh"
curl -L -o /opt/yourmedia/setup-java-tomcat.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/setup-java-tomcat.sh"
chmod +x /opt/yourmedia/setup-java-tomcat.sh

# Téléchargement du script de déploiement
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement du script deploy-war.sh"
curl -L -o /opt/yourmedia/deploy-war.sh "$GITHUB_RAW_URL/scripts/ec2-java-tomcat/deploy-war.sh"
chmod +x /opt/yourmedia/deploy-war.sh
```

### 3. Variables d'environnement

Les variables d'environnement sont maintenant gérées directement dans les scripts d'initialisation :

```bash
# Création d'un fichier env.json vide si nécessaire
echo "$(date '+%Y-%m-%d %H:%M:%S') - Création d'un fichier env.json vide"
echo '{
  "RDS_USERNAME": "",
  "RDS_PASSWORD": "",
  "RDS_ENDPOINT": "",
  "RDS_NAME": "",
  "AWS_REGION": "eu-west-3"
}' > /tmp/env.json

# Extraction des variables
RDS_USERNAME=$(jq -r '.RDS_USERNAME' /tmp/env.json)
RDS_PASSWORD=$(jq -r '.RDS_PASSWORD' /tmp/env.json)
RDS_ENDPOINT=$(jq -r '.RDS_ENDPOINT' /tmp/env.json)
RDS_NAME=$(jq -r '.RDS_NAME' /tmp/env.json)
AWS_REGION=$(jq -r '.AWS_REGION' /tmp/env.json)
EC2_INSTANCE_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Création du fichier de variables d'environnement
cat > /opt/yourmedia/secure/.env << EOF
RDS_USERNAME=$RDS_USERNAME
RDS_PASSWORD=$RDS_PASSWORD
RDS_ENDPOINT=$RDS_ENDPOINT
RDS_NAME=$RDS_NAME
AWS_REGION=$AWS_REGION
EC2_INSTANCE_PRIVATE_IP=$EC2_INSTANCE_PRIVATE_IP
EOF
```

> **Note importante** : Nous n'utilisons plus le tag S3BucketName sur les instances EC2, car les scripts sont téléchargés directement depuis GitHub.

## Configuration requise

Pour utiliser cette approche, vous devez :

1. Ajouter les variables `repo_owner` et `repo_name` aux modules Terraform.
2. Modifier les scripts d'initialisation pour télécharger les scripts depuis GitHub avec l'option `-L` pour suivre les redirections.
3. Supprimer les ressources qui copient les scripts dans le bucket S3.
4. Mettre à jour les workflows GitHub Actions pour supprimer les étapes de copie des scripts dans S3.
5. Supprimer le code qui crée et utilise le tag S3BucketName sur les instances EC2.

## Limitations

1. **Dépendance à GitHub** : Si GitHub est indisponible, les instances EC2 ne pourront pas télécharger les scripts.
2. **Accès public** : Les scripts doivent être accessibles publiquement sur GitHub.
3. **Latence** : Le téléchargement des scripts depuis GitHub peut être plus lent que depuis S3.
4. **Redirections HTTP** : Il est important d'utiliser l'option `-L` avec curl pour suivre les redirections HTTP de GitHub.

## Conclusion

Cette approche simplifie le déploiement et la maintenance des scripts d'initialisation et de configuration des instances EC2. Elle évite les problèmes de copie des scripts dans S3 et garantit que les instances EC2 utilisent toujours la dernière version des scripts.

## Résolution des problèmes courants

### Erreur 404 lors du téléchargement des scripts

Si vous rencontrez une erreur 404 lors du téléchargement des scripts depuis GitHub, assurez-vous d'utiliser l'option `-L` avec curl pour suivre les redirections HTTP :

```bash
# Incorrect
curl -s -o /opt/yourmedia/script.sh "https://raw.githubusercontent.com/user/repo/main/path/to/script.sh"

# Correct
curl -L -o /opt/yourmedia/script.sh "https://raw.githubusercontent.com/user/repo/main/path/to/script.sh"
```

### Problèmes avec les tags EC2

Nous avons supprimé le code qui crée et utilise le tag S3BucketName sur les instances EC2, car il n'est plus nécessaire avec notre nouvelle approche. Si vous rencontrez des erreurs liées à ce tag, assurez-vous que tous les scripts ont été mis à jour pour ne plus l'utiliser.
