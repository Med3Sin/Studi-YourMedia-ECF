# Gestion de l'état Terraform (tfstate) avec Terraform Cloud

Ce document explique comment les workflows de déploiement (`apply`) et de destruction (`destroy`) utilisent le même état Terraform (tfstate) stocké sur Terraform Cloud.

## Principe de fonctionnement

Dans le projet YourMédia, l'état Terraform (tfstate) est stocké de manière centralisée sur Terraform Cloud. Cette approche présente plusieurs avantages :

1. **Cohérence** : Tous les workflows utilisent le même état, garantissant que les opérations `apply` et `destroy` sont cohérentes
2. **Sécurité** : L'état Terraform contient des informations sensibles qui sont stockées de manière sécurisée
3. **Collaboration** : Plusieurs développeurs peuvent travailler sur l'infrastructure sans risque de conflits
4. **Verrouillage d'état** : Terraform Cloud gère automatiquement le verrouillage de l'état pour éviter les modifications simultanées

## Configuration du backend Terraform Cloud

La configuration du backend Terraform Cloud est définie dans le fichier `infrastructure/providers.tf` :

```hcl
terraform {
  # Configuration du backend Terraform Cloud
  cloud {
    organization = "Med3Sin"
    workspaces {
      name = "Med3Sin-CLI"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}
```

Cette configuration indique à Terraform d'utiliser Terraform Cloud comme backend pour stocker l'état, avec :
- L'organisation `Med3Sin`
- Le workspace `Med3Sin-CLI`

## Workflow GitHub Actions

Les workflows GitHub Actions (`1-infra-deploy-destroy.yml`) sont configurés pour utiliser ce backend Terraform Cloud :

### 1. Configuration de l'authentification Terraform Cloud

```yaml
# Créer un fichier de configuration pour l'API Terraform Cloud
cat > ~/.terraformrc << EOF
credentials "app.terraform.io" {
  token = "${{ secrets.TF_API_TOKEN }}"
}
EOF
```

Cette étape crée un fichier de configuration Terraform qui contient le token d'API pour s'authentifier auprès de Terraform Cloud.

### 2. Initialisation de Terraform

```yaml
# Initialiser Terraform
terraform init
```

Lors de l'initialisation, Terraform se connecte à Terraform Cloud en utilisant le token d'API et configure le backend pour stocker l'état.

### 3. Opérations Terraform (Plan, Apply, Destroy)

Que ce soit pour les opérations `plan`, `apply` ou `destroy`, Terraform utilise le même état stocké sur Terraform Cloud :

- **Plan** : Terraform récupère l'état actuel depuis Terraform Cloud, puis calcule les modifications à apporter
- **Apply** : Terraform applique les modifications et met à jour l'état sur Terraform Cloud
- **Destroy** : Terraform récupère l'état actuel depuis Terraform Cloud, puis supprime les ressources et met à jour l'état

## Vérification de l'utilisation du même état

Pour vérifier que les workflows utilisent bien le même état Terraform, vous pouvez :

1. **Consulter l'interface Terraform Cloud** :
   - Connectez-vous à [Terraform Cloud](https://app.terraform.io/)
   - Accédez à l'organisation `Med3Sin` et au workspace `Med3Sin-CLI`
   - Consultez l'onglet "States" pour voir l'historique des états

2. **Examiner les logs des workflows GitHub Actions** :
   - Dans les logs d'initialisation (`terraform init`), vous devriez voir un message indiquant que Terraform est configuré pour utiliser le backend Terraform Cloud
   - Les opérations `apply` et `destroy` devraient indiquer qu'elles utilisent l'état stocké sur Terraform Cloud

## Gestion des environnements

Bien que nous utilisions un seul workspace Terraform Cloud, les environnements (dev, pre-prod, prod) sont gérés via la variable `environment` :

```yaml
-var="environment=${{ github.event.inputs.environment }}"
```

Cette approche permet de déployer plusieurs environnements tout en utilisant le même état Terraform. Cependant, cela signifie que :

1. L'état contient les informations de tous les environnements
2. Il faut être prudent lors des opérations de destruction pour ne pas affecter d'autres environnements
3. Les noms des ressources incluent l'environnement pour éviter les conflits (ex: `yourmedia-dev-ec2`, `yourmedia-prod-ec2`)

## Bonnes pratiques

1. **Ne jamais modifier manuellement l'état** : Toutes les modifications doivent passer par les workflows GitHub Actions
2. **Vérifier les plans avant d'appliquer** : Utilisez l'action "plan" pour vérifier les modifications avant de les appliquer
3. **Sauvegarder régulièrement l'état** : Terraform Cloud effectue des sauvegardes automatiques, mais vous pouvez également exporter l'état manuellement
4. **Utiliser le verrouillage d'état** : Terraform Cloud verrouille automatiquement l'état pendant les opérations pour éviter les conflits
5. **Surveiller les versions de l'état** : Terraform Cloud conserve un historique des versions de l'état, ce qui permet de revenir en arrière si nécessaire

## Résolution des problèmes courants

### Erreur : "Error: Failed to load state"

Si vous rencontrez cette erreur, vérifiez que :
1. Le token d'API Terraform Cloud (`TF_API_TOKEN`) est correctement configuré
2. L'organisation et le workspace sont correctement configurés dans `providers.tf`
3. Le workspace existe sur Terraform Cloud

### Erreur : "Error: State locked"

Si l'état est verrouillé, cela signifie qu'une autre opération est en cours. Vous pouvez :
1. Attendre que l'opération se termine
2. Vérifier dans l'interface Terraform Cloud si une opération est bloquée
3. Déverrouiller manuellement l'état dans l'interface Terraform Cloud (à utiliser avec précaution)

### Erreur : "Error: Conflict with another remote state"

Cette erreur peut survenir si plusieurs workflows tentent de modifier l'état simultanément. Assurez-vous qu'un seul workflow est exécuté à la fois.

## Conclusion

L'utilisation de Terraform Cloud pour stocker l'état Terraform garantit que les workflows de déploiement (`apply`) et de destruction (`destroy`) utilisent le même état, ce qui assure la cohérence des opérations d'infrastructure. Cette approche centralisée simplifie la gestion de l'infrastructure et renforce la sécurité en stockant l'état de manière sécurisée.
