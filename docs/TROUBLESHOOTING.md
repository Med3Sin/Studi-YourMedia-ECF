# Guide de résolution des problèmes - YourMédia

Ce document centralise les problèmes connus et leurs solutions pour le projet YourMédia.

## Table des matières

1. [Problèmes des workflows GitHub Actions](#problèmes-des-workflows-github-actions)
   - [Erreur lors du vidage du bucket S3](#erreur-lors-du-vidage-du-bucket-s3)
   - [Avertissements de commandes dépréciées](#avertissements-de-commandes-dépréciées)
2. [Problèmes d'infrastructure](#problèmes-dinfrastructure)
   - [Échec de la destruction de l'infrastructure](#échec-de-la-destruction-de-linfrastructure)
   - [Problèmes avec les variables dans les templates Terraform](#problèmes-avec-les-variables-dans-les-templates-terraform)
3. [Problèmes de déploiement](#problèmes-de-déploiement)
   - [Échec du déploiement du backend](#échec-du-déploiement-du-backend)
   - [Échec du déploiement du frontend](#échec-du-déploiement-du-frontend)
4. [Problèmes de monitoring](#problèmes-de-monitoring)
   - [Problèmes de permissions Grafana/Prometheus](#problèmes-de-permissions-grafanaprometheus)
   - [Métriques manquantes](#métriques-manquantes)

## Problèmes des workflows GitHub Actions

### Erreur lors du vidage du bucket S3

**Problème** : Le workflow de destruction de l'infrastructure échoue avec l'erreur suivante lors de l'étape de vidage du bucket S3 :

```
Run echo "::group::Vidage du bucket S3"
Vidage du bucket S3
  /home/runner/work/_temp/da3b5d38-1c44-4c46-9acf-4545740c1bce.sh: line 3: cd: infrastructure: No such file or directory
  Error: Process completed with exit code 1.
```

**Cause** : Le workflow tente de changer de répertoire vers "infrastructure" alors qu'il est déjà dans ce répertoire. Cela est dû à la configuration du job qui définit déjà le répertoire de travail.

**Solution** : La ligne `cd infrastructure` a été supprimée du script de vidage du bucket S3 dans le fichier `.github/workflows/1-infra-deploy-destroy.yml`.

### Avertissements de commandes dépréciées

**Problème** : Le workflow affiche des avertissements concernant l'utilisation de commandes dépréciées :

```
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
```

**Cause** : L'action `gliech/create-github-secret-action@v1` utilise la commande `set-output` qui est dépréciée par GitHub Actions.

**Solution** : Ces avertissements n'empêchent pas le workflow de fonctionner correctement. Pour les éliminer, il faudrait mettre à jour l'action vers une version plus récente ou utiliser une action alternative qui utilise les fichiers d'environnement au lieu de `set-output`.

## Problèmes d'infrastructure

### Échec de la destruction de l'infrastructure

**Problème** : La destruction de l'infrastructure échoue avec une erreur concernant le bucket S3 non vide.

**Cause** : Terraform ne peut pas détruire un bucket S3 qui contient des objets.

**Solution** : Le workflow a été modifié pour vider automatiquement le bucket S3 avant de tenter de le détruire. Si le problème persiste, vous pouvez vider manuellement le bucket S3 via la console AWS ou la commande AWS CLI :

```bash
aws s3 rm s3://<NOM_DU_BUCKET> --recursive
```

### Problèmes avec les variables dans les templates Terraform

**Problème** : Erreur lors de la validation Terraform indiquant qu'une variable référencée dans un template n'existe pas dans la map de variables.

```
Error: Invalid function argument

Invalid value for "vars" parameter: vars map does not contain key "ec2_java_tomcat_ip", referenced at modules/s3/../ec2-monitoring/scripts/setup.sh:27,14-32.
```

**Cause** : Une variable est référencée dans un template Terraform mais n'est pas définie dans la map de variables passée à la fonction `templatefile()`.

**Solution** : Assurez-vous que toutes les variables référencées dans les templates sont définies dans la map de variables passée à la fonction `templatefile()`.

## Problèmes de déploiement

### Échec du déploiement du backend

**Problème** : Le déploiement du backend échoue avec une erreur SSH.

**Cause** : Problème de connexion SSH à l'instance EC2.

**Solution** :
1. Vérifiez que l'instance EC2 est en cours d'exécution
2. Vérifiez que le groupe de sécurité autorise les connexions SSH (port 22)
3. Vérifiez que la clé SSH privée est correctement configurée dans les secrets GitHub
4. Vérifiez que l'utilisateur SSH est correct (ec2-user pour Amazon Linux)

### Échec du déploiement du frontend

**Problème** : Le déploiement du frontend échoue avec une erreur de compilation.

**Cause** : Problème de compilation du code React.

**Solution** :
1. Vérifiez que les dépendances sont correctement installées
2. Vérifiez que le code ne contient pas d'erreurs de syntaxe
3. Vérifiez que les variables d'environnement sont correctement configurées

## Problèmes de monitoring

### Problèmes de permissions Grafana/Prometheus

**Problème** : Les conteneurs Docker pour Grafana et Prometheus rencontrent des problèmes de permissions lorsqu'ils tentent d'écrire dans les volumes montés.

**Cause** : Les permissions des répertoires de données ne sont pas correctement configurées.

**Solution** : Exécutez le script de correction des permissions :

```bash
# Se connecter à l'instance EC2
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>

# Exécuter le script de correction des permissions
sudo /opt/monitoring/fix_permissions.sh
```

### Métriques manquantes

**Problème** : Certaines métriques sont manquantes dans Grafana.

**Cause** : Problème de configuration de Prometheus ou des exportateurs.

**Solution** :
1. Vérifiez que Prometheus est en cours d'exécution
2. Vérifiez que les exportateurs sont en cours d'exécution
3. Vérifiez que les cibles sont correctement configurées dans Prometheus
4. Vérifiez que les dashboards Grafana sont correctement configurés
