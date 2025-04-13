# Gestion des profils IAM persistants

Ce document explique comment gérer les profils IAM qui peuvent persister après la destruction de l'infrastructure Terraform.

## Problème

Lors de l'exécution de `terraform destroy`, certaines ressources IAM, notamment les profils d'instance IAM, peuvent ne pas être correctement supprimées. Cela provoque des erreurs lors des déploiements ultérieurs :

```
Error: creating IAM Instance Profile (yourmedia-dev-ec2-profile): operation error IAM: CreateInstanceProfile, https response error StatusCode: 409, RequestID: 29837bb2-e2df-4606-9580-375b7711a933, EntityAlreadyExists: Instance Profile yourmedia-dev-ec2-profile already exists.
```

## Solution

Nous avons mis en place deux mécanismes pour résoudre ce problème :

### 1. Configuration des ressources IAM dans Terraform

Les ressources IAM ont été configurées avec des options qui facilitent leur suppression :

- Ajout de `force_detach_policies = true` aux rôles IAM pour forcer le détachement des politiques lors de la suppression
- Ajout de `lifecycle { create_before_destroy = true }` aux rôles et profils IAM pour créer de nouvelles ressources avant de supprimer les anciennes

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role-v2"
  force_detach_policies = true
  
  # ... autres configurations ...
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
  
  # ... autres configurations ...
  
  lifecycle {
    create_before_destroy = true
  }
}
```

### 2. Nettoyage automatique dans le workflow GitHub Actions

Le workflow GitHub Actions `1-infra-deploy-destroy.yml` inclut maintenant une étape de nettoyage qui s'exécute après `terraform destroy` pour supprimer manuellement les profils IAM persistants :

```yaml
- name: Cleanup IAM Profiles
  if: github.event.inputs.action == 'destroy'
  run: |
    # Définir les noms des ressources IAM à nettoyer
    PROJECT_NAME="yourmedia"
    ENVIRONMENT="${{ github.event.inputs.environment }}"
    EC2_PROFILE="${PROJECT_NAME}-${ENVIRONMENT}-ec2-profile"
    MONITORING_PROFILE="${PROJECT_NAME}-${ENVIRONMENT}-monitoring-profile"
    
    # Fonction pour supprimer un profil IAM
    delete_instance_profile() {
      local profile_name=$1
      # Vérifier si le profil existe
      if aws iam get-instance-profile --instance-profile-name $profile_name 2>/dev/null; then
        # Récupérer les rôles attachés au profil
        ROLES=$(aws iam get-instance-profile --instance-profile-name $profile_name --query "InstanceProfile.Roles[*].RoleName" --output text)
        
        # Détacher les rôles du profil
        for role in $ROLES; do
          aws iam remove-role-from-instance-profile --instance-profile-name $profile_name --role-name $role
        done
        
        # Supprimer le profil
        aws iam delete-instance-profile --instance-profile-name $profile_name
      fi
    }
    
    # Supprimer les profils IAM
    delete_instance_profile $EC2_PROFILE
    delete_instance_profile $MONITORING_PROFILE
```

## Utilisation

Aucune action manuelle n'est nécessaire. Le nettoyage des profils IAM est automatiquement effectué lors de l'exécution de l'action `destroy` dans le workflow GitHub Actions.

Si vous avez besoin de nettoyer manuellement les profils IAM, vous pouvez utiliser les commandes AWS CLI suivantes :

```bash
# Détacher le rôle du profil
aws iam remove-role-from-instance-profile --instance-profile-name yourmedia-dev-ec2-profile --role-name yourmedia-dev-ec2-role-v2

# Supprimer le profil
aws iam delete-instance-profile --instance-profile-name yourmedia-dev-ec2-profile
```

## Remarques

- Cette solution garantit que les profils IAM sont correctement supprimés, même si `terraform destroy` échoue à les supprimer.
- L'option `continue-on-error: true` dans le workflow permet de continuer l'exécution même si `terraform destroy` échoue, afin de pouvoir exécuter l'étape de nettoyage.
- Les noms des ressources IAM sont codés en dur dans le workflow pour simplifier la configuration.
