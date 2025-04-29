# Guide de nettoyage de l'infrastructure - YourMédia

Ce document explique comment nettoyer complètement l'infrastructure YourMédia, y compris les conteneurs Docker, les images Docker Hub, et toutes les ressources AWS.

## Table des matières

1. [Introduction](#introduction)
2. [Processus de nettoyage](#processus-de-nettoyage)
3. [Nettoyage manuel](#nettoyage-manuel)
4. [Vérification du nettoyage](#vérification-du-nettoyage)
5. [Résolution des problèmes](#résolution-des-problèmes)

## Introduction

Le nettoyage complet de l'infrastructure est important pour éviter des coûts inutiles et pour maintenir un environnement propre. Le workflow `1-infra-deploy-destroy.yml` a été amélioré pour nettoyer automatiquement les conteneurs Docker et les ressources AWS.

## Processus de nettoyage

Le processus de nettoyage est divisé en deux workflows distincts :

### 1. Nettoyage de l'infrastructure AWS (Workflow 1)

Ce workflow gère le nettoyage de l'infrastructure AWS et comprend les étapes suivantes :

1. **Arrêt et suppression des conteneurs Docker** : Le workflow arrête et supprime tous les conteneurs Docker sur les instances EC2 avant de détruire l'infrastructure.
2. **Vidage du bucket S3** : Le workflow vide le bucket S3 avant de le supprimer.
3. **Destruction de l'infrastructure Terraform** : Le workflow utilise `terraform destroy` pour supprimer toutes les ressources créées par Terraform.
4. **Nettoyage des profils IAM persistants** : Le workflow nettoie les profils IAM qui pourraient persister après la destruction de l'infrastructure.

#### Exécution du workflow de nettoyage de l'infrastructure

Pour exécuter le workflow de nettoyage de l'infrastructure :

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "1 - Deploy/Destroy Infrastructure (Terraform)"
3. Cliquez sur "Run workflow"
4. Sélectionnez l'action "destroy"
5. Sélectionnez l'environnement à nettoyer (dev, pre-prod, prod)
6. Cliquez sur "Run workflow"

### 2. Nettoyage des images Docker Hub (Workflow 5)

Ce workflow gère le nettoyage des images Docker Hub et permet de supprimer les images obsolètes ou inutilisées.

#### Exécution du workflow de nettoyage des images Docker Hub

Pour exécuter le workflow de nettoyage des images Docker Hub :

1. Accédez à l'onglet "Actions" de votre dépôt GitHub
2. Sélectionnez le workflow "5 - Docker Images Cleanup"
3. Cliquez sur "Run workflow"
4. Configurez les paramètres suivants :
   - **Dépôt Docker Hub à nettoyer** : Le nom du dépôt Docker Hub (par défaut : `medsin/yourmedia-ecf`)
   - **Motif de tag à supprimer** : Le motif de tag à supprimer (par exemple : `*-latest`, `grafana-*`, `all` pour tous les tags)
   - **Mode simulation** : Activez cette option pour simuler la suppression sans réellement supprimer les images
5. Cliquez sur "Run workflow"

> **Note** : Il est recommandé d'exécuter d'abord le workflow en mode simulation pour vérifier quelles images seront supprimées, puis de l'exécuter à nouveau avec le mode simulation désactivé pour supprimer réellement les images.

## Nettoyage manuel

Si le nettoyage automatique échoue, vous pouvez effectuer un nettoyage manuel :

### 1. Nettoyage des conteneurs Docker

Connectez-vous à chaque instance EC2 via SSH et exécutez les commandes suivantes :

```bash
# Arrêter tous les conteneurs
sudo docker stop $(sudo docker ps -aq)

# Supprimer tous les conteneurs
sudo docker rm $(sudo docker ps -aq)

# Supprimer toutes les images
sudo docker rmi $(sudo docker images -q)

# Supprimer tous les volumes
sudo docker volume rm $(sudo docker volume ls -q)

# Supprimer tous les réseaux personnalisés
sudo docker network rm $(sudo docker network ls -q -f "type=custom")

# Supprimer les fichiers de configuration Docker
sudo rm -rf /opt/monitoring /opt/app-mobile
```

### 2. Nettoyage des images Docker Hub

Si vous souhaitez supprimer manuellement les images Docker Hub :

#### Option 1 : Utilisation de l'interface web Docker Hub

1. Connectez-vous à Docker Hub : https://hub.docker.com
2. Accédez à votre dépôt : https://hub.docker.com/repository/docker/medsin/yourmedia-ecf/general
3. Sélectionnez les images à supprimer
4. Cliquez sur "Delete"

#### Option 2 : Utilisation de l'API Docker Hub

Vous pouvez également utiliser l'API Docker Hub pour supprimer les images :

```bash
# Obtenir un token d'authentification
TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "votre_username", "password": "votre_token"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

# Supprimer une image spécifique
curl -X DELETE -H "Authorization: Bearer $TOKEN" https://hub.docker.com/v2/repositories/medsin/yourmedia-ecf/tags/nom_du_tag/
```

### 3. Nettoyage des ressources AWS

Si certaines ressources AWS persistent après l'exécution du workflow de destruction, vous pouvez les supprimer manuellement via la console AWS :

1. **EC2** : Terminez les instances EC2 restantes
2. **RDS** : Supprimez les instances RDS restantes
3. **S3** : Videz et supprimez les buckets S3 restants
4. **IAM** : Supprimez les rôles et profils IAM restants
5. **VPC** : Supprimez les VPC, sous-réseaux, groupes de sécurité, et passerelles Internet restants
6. **Conteneurs Docker** : Supprimez les conteneurs Docker restants

## Vérification du nettoyage

Pour vérifier que toutes les ressources ont été correctement nettoyées :

1. **AWS** : Vérifiez la console AWS pour vous assurer qu'aucune ressource n'est encore active
2. **Docker Hub** : Vérifiez que les images Docker Hub ont été supprimées si nécessaire
3. **GitHub** : Vérifiez que les secrets GitHub liés à l'infrastructure ont été supprimés si nécessaire

## Résolution des problèmes

### Ressources persistantes

Si certaines ressources persistent après l'exécution du workflow de destruction, cela peut être dû à des dépendances entre les ressources. Dans ce cas, vous devez supprimer les ressources manuellement dans l'ordre suivant :

1. Instances EC2
2. Instances RDS
3. Buckets S3
4. Groupes de sécurité
5. Sous-réseaux
6. VPC
7. Rôles et profils IAM

### Erreurs de suppression

Si vous rencontrez des erreurs lors de la suppression des ressources, consultez les logs du workflow pour identifier la cause de l'erreur. Les erreurs courantes incluent :

- **Ressources en cours d'utilisation** : Certaines ressources peuvent être en cours d'utilisation par d'autres ressources. Dans ce cas, vous devez d'abord supprimer les ressources dépendantes.
- **Permissions insuffisantes** : Assurez-vous que l'utilisateur AWS a les permissions nécessaires pour supprimer les ressources.
- **Ressources protégées** : Certaines ressources peuvent être protégées contre la suppression. Dans ce cas, vous devez d'abord désactiver la protection.

Si vous ne parvenez pas à résoudre les erreurs, contactez l'administrateur AWS pour obtenir de l'aide.
