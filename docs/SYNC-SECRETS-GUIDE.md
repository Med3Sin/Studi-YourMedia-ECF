# Guide de synchronisation des secrets GitHub vers Terraform Cloud

Ce document explique comment synchroniser les secrets GitHub vers Terraform Cloud pour centraliser la gestion des secrets.

## Objectif

L'objectif est de centraliser la gestion des secrets dans GitHub Secrets et de les synchroniser automatiquement vers Terraform Cloud pour qu'ils soient accessibles par Terraform lors du déploiement de l'infrastructure.

## Prérequis

- Un compte GitHub avec des secrets configurés
- Un compte Terraform Cloud avec un workspace configuré
- Un token d'API Terraform Cloud avec les permissions appropriées
- Un token d'API GitHub avec les permissions appropriées

## Utilisation du script de synchronisation

Le script `scripts/utils/sync-github-secrets-to-terraform.sh` permet de synchroniser les secrets GitHub vers Terraform Cloud. Il peut être exécuté manuellement ou via un workflow GitHub Actions.

### Exécution manuelle

```bash
export GITHUB_TOKEN=<votre_token_github>
export TF_API_TOKEN=<votre_token_terraform_cloud>
export GITHUB_REPOSITORY=<votre_repository_github>
export TF_WORKSPACE_ID=<votre_workspace_terraform_cloud>
./scripts/utils/sync-github-secrets-to-terraform.sh
```

### Exécution via GitHub Actions

Le workflow `sync-secrets-to-terraform.yml` permet d'exécuter le script de synchronisation automatiquement après le déploiement de l'infrastructure.

## Fonctionnement

1. Le script récupère la liste des secrets GitHub via l'API GitHub
2. Pour chaque secret, il vérifie s'il existe déjà dans Terraform Cloud
3. Si le secret existe, il le met à jour avec la valeur actuelle
4. Si le secret n'existe pas, il le crée dans Terraform Cloud
5. Les secrets sont marqués comme sensibles ou non en fonction de leur nom

## Sécurité

- Les valeurs des secrets ne sont jamais affichées dans les logs
- Les secrets sont marqués comme sensibles dans Terraform Cloud
- Les tokens d'API sont stockés en tant que secrets GitHub

## Limitations

- Les valeurs des secrets GitHub ne sont pas accessibles directement via l'API GitHub
- Le script doit être exécuté dans un environnement où les valeurs des secrets sont disponibles (comme GitHub Actions)
- Les secrets qui contiennent des caractères spéciaux peuvent nécessiter un traitement particulier

## Dépannage

Si vous rencontrez des problèmes lors de la synchronisation des secrets, vérifiez les points suivants :

1. Les tokens d'API sont valides et ont les permissions appropriées
2. Les variables d'environnement requises sont définies
3. Le workspace Terraform Cloud existe et est accessible
4. Les dépendances (curl, jq) sont installées

## Références

- [API GitHub pour les secrets](https://docs.github.com/en/rest/actions/secrets)
- [API Terraform Cloud pour les variables](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/variables)
