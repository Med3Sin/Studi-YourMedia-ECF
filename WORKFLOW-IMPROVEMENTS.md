# Corrections et Améliorations des Workflows GitHub Actions

Ce document détaille les corrections et améliorations apportées aux workflows GitHub Actions du projet YourMédia. Il vise à expliquer les problèmes rencontrés, les solutions mises en œuvre et les bonnes pratiques adoptées.

## Table des matières

1. [Correction du workflow de déploiement backend](#1-correction-du-workflow-de-déploiement-backend)
2. [Amélioration du workflow de déploiement frontend](#2-amélioration-du-workflow-de-déploiement-frontend)
3. [Bonnes pratiques pour les workflows GitHub Actions](#3-bonnes-pratiques-pour-les-workflows-github-actions)
4. [Résolution des problèmes courants](#4-résolution-des-problèmes-courants)

## 1. Correction du workflow de déploiement backend

### Problème identifié

Le workflow de déploiement backend (`.github/workflows/2-backend-deploy.yml`) présentait une erreur de syntaxe à la ligne 115 :

```yaml
echo "* **URL de l'application:** http://${{ github.event.inputs.ec2_public_ip }}:8080/${{ env.WAR_NAME | replace: '.war', '' }}/" >> $GITHUB_STEP_SUMMARY
```

L'erreur spécifique était :
```
Invalid workflow file: .github/workflows/2-backend-deploy.yml#L110
The workflow is not valid. .github/workflows/2-backend-deploy.yml (Line: 110, Col: 14): Unexpected symbol: '|'. Located at position 14 within expression: env.WAR_NAME | replace: '.war', ''
```

Le problème venait de l'utilisation de l'opérateur `|` (pipe) avec la fonction `replace` dans une expression GitHub Actions. Cette syntaxe, inspirée de Liquid/Jekyll, n'est pas prise en charge dans GitHub Actions.

### Solution mise en œuvre

La solution a consisté à remplacer cette approche par une solution en deux étapes utilisant les commandes shell :

```yaml
# Extraction du nom de l'application sans l'extension .war
WAR_NAME_WITHOUT_EXTENSION=$(echo "${{ env.WAR_NAME }}" | sed 's/\.war$//')
echo "* **URL de l'application:** http://${{ github.event.inputs.ec2_public_ip }}:8080/${WAR_NAME_WITHOUT_EXTENSION}/" >> $GITHUB_STEP_SUMMARY
```

Cette solution :
1. Utilise la commande `sed` pour supprimer l'extension `.war` du nom du fichier
2. Stocke le résultat dans une variable shell `WAR_NAME_WITHOUT_EXTENSION`
3. Utilise cette variable dans l'URL de l'application

## 2. Amélioration du workflow de déploiement frontend

### Problème identifié

Le workflow de déploiement frontend (`.github/workflows/3-frontend-deploy.yml`) échouait avec l'erreur suivante :

```
Error: Dependencies lock file is not found in /home/runner/work/Studi-YourMedia-ECF/Studi-YourMedia-ECF. Supported file patterns: package-lock.json,npm-shrinkwrap.json,yarn.lock
```

Le problème était que l'action `actions/setup-node@v4` tentait de mettre en cache les dépendances à la racine du projet, mais les dépendances se trouvent dans le sous-répertoire `app-react`.

### Solutions mises en œuvre

#### 1. Détection automatique du gestionnaire de paquets

Ajout d'une étape qui détecte automatiquement le gestionnaire de paquets (npm ou yarn) en fonction des fichiers de verrouillage présents :

```yaml
# Étape 2: Détection du gestionnaire de paquets
- name: Detect package manager
  id: detect-package-manager
  run: |
    if [ -f "${{ env.APP_DIR }}/yarn.lock" ]; then
      echo "PACKAGE_MANAGER=yarn" >> $GITHUB_ENV
      echo "LOCK_FILE=yarn.lock" >> $GITHUB_ENV
    else
      echo "PACKAGE_MANAGER=npm" >> $GITHUB_ENV
      echo "LOCK_FILE=package-lock.json" >> $GITHUB_ENV
    fi
    echo "Using ${{ env.PACKAGE_MANAGER }} as package manager"
```

#### 2. Spécification du chemin correct pour le cache des dépendances

Modification de la configuration de Node.js pour spécifier le chemin correct vers le fichier de verrouillage des dépendances :

```yaml
# Étape 3: Configuration de Node.js
- name: Set up Node.js ${{ env.NODE_VERSION }}
  uses: actions/setup-node@v4
  with:
    node-version: ${{ env.NODE_VERSION }}
    cache: ${{ env.PACKAGE_MANAGER }}
    cache-dependency-path: ${{ env.APP_DIR }}/${{ env.LOCK_FILE }}
```

#### 3. Réorganisation des étapes du workflow

Réorganisation et renumérotation des étapes du workflow pour maintenir la cohérence :
- Étape 1 : Récupération du code source
- Étape 2 : Détection du gestionnaire de paquets
- Étape 3 : Configuration de Node.js
- Étape 4 : Installation des dépendances
- Étape 5 : Compilation de l'application web
- Étape 6 : Linting et tests (optionnelle)

## 3. Bonnes pratiques pour les workflows GitHub Actions

### Utilisation des variables d'environnement

Les variables d'environnement sont définies au niveau du workflow et peuvent être utilisées dans toutes les étapes :

```yaml
env:
  NODE_VERSION: '18'     # Version de Node.js à utiliser
  APP_DIR: ./app-react   # Répertoire de l'application React
```

Pour définir des variables d'environnement dynamiquement pendant l'exécution du workflow, utilisez la syntaxe suivante :

```yaml
echo "VARIABLE_NAME=value" >> $GITHUB_ENV
```

### Utilisation des groupes de logs

Les groupes de logs permettent d'organiser et de réduire la verbosité des logs :

```yaml
echo "::group::Installing dependencies"
${{ env.PACKAGE_MANAGER }} install
echo "::endgroup::"
```

### Utilisation des résumés de workflow

Les résumés de workflow permettent d'afficher des informations importantes de manière structurée :

```yaml
echo "## Résumé du déploiement Backend" >> $GITHUB_STEP_SUMMARY
echo "* **Application:** Backend Java (WAR)" >> $GITHUB_STEP_SUMMARY
```

### Utilisation des répertoires de travail

Pour exécuter des commandes dans un répertoire spécifique, utilisez l'attribut `working-directory` :

```yaml
- name: Install dependencies
  run: |
    ${{ env.PACKAGE_MANAGER }} install
  working-directory: ${{ env.APP_DIR }}
```

## 4. Résolution des problèmes courants

### Problème : Erreur de syntaxe dans les expressions

**Symptôme** : Erreur `Unexpected symbol` dans les expressions.

**Solution** : 
- Évitez d'utiliser des opérateurs ou des fonctions non prises en charge dans les expressions GitHub Actions.
- Utilisez des commandes shell pour les manipulations de chaînes complexes.

### Problème : Fichier de verrouillage des dépendances non trouvé

**Symptôme** : Erreur `Dependencies lock file is not found`.

**Solution** :
- Spécifiez le chemin correct vers le fichier de verrouillage des dépendances avec l'attribut `cache-dependency-path`.
- Assurez-vous que le fichier de verrouillage des dépendances existe dans le répertoire spécifié.

### Problème : Erreur d'accès aux secrets

**Symptôme** : Avertissement `Context access might be invalid: secrets.SECRET_NAME`.

**Solution** :
- Cet avertissement est normal dans l'IDE et n'affecte pas le fonctionnement du workflow.
- Assurez-vous que le secret est correctement défini dans les paramètres du dépôt GitHub.

### Problème : Erreur d'accès aux variables d'environnement dynamiques

**Symptôme** : Avertissement `Context access might be invalid: env.VARIABLE_NAME`.

**Solution** :
- Cet avertissement est normal pour les variables définies dynamiquement pendant l'exécution du workflow.
- Les variables seront correctement résolues lors de l'exécution du workflow.
