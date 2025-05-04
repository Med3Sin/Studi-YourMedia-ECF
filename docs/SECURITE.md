# Guide de Sécurité - YourMedia

Ce document centralise toutes les informations relatives à la sécurité dans le projet YourMedia.

## Table des matières

1. [Vue d'ensemble de la sécurité](#1-vue-densemble-de-la-sécurité)
2. [Sécurité des instances EC2](#2-sécurité-des-instances-ec2)
   - [Groupes de sécurité](#21-groupes-de-sécurité)
   - [Gestion des clés SSH](#22-gestion-des-clés-ssh)
3. [Sécurité des conteneurs Docker](#3-sécurité-des-conteneurs-docker)
   - [Bonnes pratiques](#31-bonnes-pratiques)
   - [Scan des vulnérabilités](#32-scan-des-vulnérabilités)
   - [Variables d'environnement sensibles](#33-variables-denvironnement-sensibles)
4. [Sécurité des scripts](#4-sécurité-des-scripts)
   - [Permissions](#41-permissions)
   - [Gestion des secrets](#42-gestion-des-secrets)
5. [Améliorations pour un environnement de production](#5-améliorations-pour-un-environnement-de-production)
   - [Restriction des accès](#51-restriction-des-accès)
   - [Gestion des secrets](#52-gestion-des-secrets)
   - [Chiffrement des données](#53-chiffrement-des-données)
   - [Conformité et audit](#54-conformité-et-audit)

## 1. Vue d'ensemble de la sécurité

Le projet YourMedia implémente plusieurs mesures de sécurité de base, mais dans un contexte académique. Pour un environnement de production réel, des mesures supplémentaires seraient nécessaires.

Les principales mesures de sécurité actuellement en place sont :
- Groupes de sécurité AWS pour contrôler les accès réseau
- Gestion des clés SSH pour l'accès aux instances EC2
- Scan des vulnérabilités des images Docker avec Trivy
- Permissions appropriées pour les scripts et les fichiers sensibles
- Stockage sécurisé des secrets dans GitHub Secrets

## 2. Sécurité des instances EC2

### 2.1. Groupes de sécurité

Les groupes de sécurité AWS sont utilisés pour contrôler le trafic entrant et sortant des instances EC2 :

- **EC2 Java/Tomcat** :
  - Port 22 (SSH) : Ouvert pour l'accès administratif
  - Port 8080 (Tomcat) : Ouvert pour l'accès à l'application

- **EC2 Monitoring** :
  - Port 22 (SSH) : Ouvert pour l'accès administratif
  - Port 3000 (Grafana) : Ouvert pour l'accès au dashboard
  - Port 9090 (Prometheus) : Restreint aux instances du même groupe de sécurité
  - Port 8080 (Application React) : Ouvert pour l'accès à l'application

**Situation actuelle :** Pour simplifier le projet, les accès SSH sont ouverts à toutes les adresses IP (`0.0.0.0/0`).

**Recommandation :** Dans un environnement de production, restreindre l'accès SSH aux adresses IP des administrateurs système.

### 2.2. Gestion des clés SSH

Les clés SSH sont utilisées pour l'accès sécurisé aux instances EC2 :

#### Problème des guillemets dans les clés SSH

Un problème courant est l'apparition de guillemets simples (') entourant les clés SSH dans le fichier `authorized_keys`. Ces guillemets peuvent être ajoutés lors du déploiement de l'infrastructure, notamment lorsque les clés SSH sont passées via des variables d'environnement ou des secrets GitHub.

#### Solution automatisée

Pour résoudre ce problème, nous avons mis en place une solution automatisée qui :

1. **Prévient le problème** : Les scripts d'initialisation des instances EC2 suppriment automatiquement les guillemets simples des clés SSH avant de les ajouter au fichier `authorized_keys`.

2. **Corrige le problème existant** : Un script de correction des clés SSH est exécuté automatiquement après le déploiement de l'infrastructure.

3. **Vérifie périodiquement** : Un service systemd vérifie et corrige périodiquement le format des clés SSH.

#### Vérification des clés SSH

Pour vérifier que les clés SSH sont correctement formatées :

```bash
cat ~/.ssh/authorized_keys
```

Les clés SSH valides doivent commencer par `ssh-rsa`, `ssh-ed25519`, etc., sans guillemets simples au début ou à la fin.

## 3. Sécurité des conteneurs Docker

### 3.1. Bonnes pratiques

1. **Utiliser des images de base officielles et à jour**
   - Préférer les images officielles (Docker Hub)
   - Utiliser des tags spécifiques plutôt que `latest`
   - Mettre régulièrement à jour les images de base

2. **Minimiser la taille des images**
   - Utiliser des images de base légères (Alpine, slim, etc.)
   - Nettoyer les caches et les fichiers temporaires
   - Utiliser des builds multi-étapes

3. **Exécuter les conteneurs avec des utilisateurs non-root**
   - Éviter d'utiliser l'utilisateur `root` dans les conteneurs
   - Créer et utiliser des utilisateurs spécifiques
   - Définir les permissions appropriées

4. **Limiter les capacités et les ressources**
   - Limiter les capacités Linux avec `--cap-drop`
   - Définir des limites de ressources (CPU, mémoire)
   - Utiliser des politiques de sécurité pour restreindre les actions dangereuses

### 3.2. Scan des vulnérabilités

Le projet utilise Trivy pour scanner les vulnérabilités dans les images Docker :

#### Options de scan optimisées

```bash
# Limiter le scan aux vulnérabilités uniquement
trivy image --scanners vuln <image>

# Filtrer par niveau de sévérité
trivy image --severity HIGH,CRITICAL <image>

# Combiner les options
trivy image --scanners vuln --severity HIGH,CRITICAL <image>
```

#### Workflow GitHub Actions

Le workflow GitHub Actions `4-analyse-de-securite.yml` utilise ces options optimisées :

- Utilisation de `--scanners vuln` pour désactiver le scan des secrets
- Utilisation de `--severity HIGH,CRITICAL` pour se concentrer sur les vulnérabilités importantes
- Génération de rapports au format HTML et JSON pour une analyse approfondie
- Affichage d'un résumé des résultats dans l'interface GitHub Actions

### 3.3. Variables d'environnement sensibles

#### Problème

Les variables d'environnement sensibles ne doivent pas être définies directement dans les Dockerfiles car :
- Elles sont visibles dans l'historique de l'image
- Elles sont accessibles à toute personne ayant accès à l'image
- Elles peuvent être exposées lors des scans de sécurité

#### Solution

1. **Ne pas définir de variables sensibles dans le Dockerfile**
   - Éviter d'utiliser `ENV` pour les variables sensibles comme les mots de passe, les tokens, etc.

2. **Fournir les variables sensibles au moment de l'exécution**
   - Utiliser des variables d'environnement lors du déploiement
   - Utiliser des secrets Docker ou Kubernetes
   - Utiliser des fichiers de configuration montés en volume

3. **Exemple d'utilisation avec docker-compose**

```yaml
version: '3'
services:
  grafana:
    image: medsin/yourmedia-ecf:grafana-latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_AUTH_ANONYMOUS_ENABLED=false
    ports:
      - "3000:3000"
```

## 4. Sécurité des scripts

### 4.1. Permissions

La plupart des scripts du projet YourMedia nécessitent des privilèges sudo pour fonctionner correctement, car ils effectuent des opérations qui nécessitent des droits d'administrateur.

#### Scripts nécessitant des privilèges sudo

| Script | Description | Exigences en matière de droits |
|--------|-------------|--------------------------------|
| `scripts/ec2-monitoring/setup.sh` | Configuration des conteneurs Docker pour le monitoring | Doit être exécuté avec sudo ou en tant que root |
| `scripts/ec2-monitoring/install-docker.sh` | Installation de Docker | Doit être exécuté avec sudo ou en tant que root |
| `scripts/ec2-java-tomcat/deploy-war.sh` | Déploiement de l'application Java sur Tomcat | Doit être exécuté avec sudo ou en tant que root |

#### Bonnes pratiques

1. **Toujours utiliser sudo** pour exécuter les scripts qui nécessitent des privilèges élevés :
   ```bash
   sudo ./script.sh
   ```

2. **Vérifier les messages d'erreur** si un script échoue, car ils peuvent indiquer un problème de droits.

3. **Ne pas exécuter les scripts en tant que root** directement, mais plutôt utiliser sudo.

### 4.2. Gestion des secrets

Les secrets (mots de passe, tokens, clés) sont gérés de la manière suivante :

1. **Stockage dans GitHub Secrets** : Les secrets sont stockés dans GitHub Secrets et transmis aux workflows GitHub Actions.

2. **Transmission aux instances EC2** : Les secrets sont transmis aux instances EC2 via des variables d'environnement ou des fichiers sécurisés.

3. **Protection des fichiers sensibles** : Les fichiers contenant des secrets ont des permissions restrictives (600) pour empêcher l'accès non autorisé.

## 5. Améliorations pour un environnement de production

### 5.1. Restriction des accès

**Situation actuelle :** 
- Les groupes de sécurité autorisent l'accès SSH depuis n'importe quelle adresse IP (`0.0.0.0/0`).
- Certains services sont accessibles depuis n'importe où sur Internet.

**Améliorations recommandées :**
- Restreindre l'accès SSH aux adresses IP des administrateurs système.
- Mettre en place un bastion host (instance de rebond) pour centraliser et sécuriser les accès SSH.
- Limiter l'accès aux services internes (Prometheus, Grafana) aux seules adresses IP nécessaires.
- Segmenter le réseau en sous-réseaux publics et privés.

### 5.2. Gestion des secrets

**Situation actuelle :**
- Les secrets sont stockés dans GitHub Secrets et transmis aux instances EC2.

**Améliorations recommandées :**
- Utiliser AWS Secrets Manager ou AWS Parameter Store pour stocker et gérer les secrets.
- Mettre en place une rotation automatique des secrets.
- Utiliser des rôles IAM et des profils d'instance pour accéder aux secrets sans les stocker sur les instances.

### 5.3. Chiffrement des données

**Situation actuelle :**
- Le chiffrement de base est utilisé pour les données au repos.

**Améliorations recommandées :**
- Activer le chiffrement des volumes EBS avec des clés KMS gérées par le client.
- Configurer le chiffrement en transit pour toutes les communications entre les services.
- Mettre en place le chiffrement des sauvegardes et des snapshots.

### 5.4. Conformité et audit

**Situation actuelle :**
- Pas de mécanismes formels d'audit et de conformité.

**Améliorations recommandées :**
- Mettre en place des contrôles pour la conformité aux réglementations applicables (RGPD, PCI DSS, etc.).
- Configurer AWS Config pour surveiller la conformité de l'infrastructure.
- Mettre en place des audits de sécurité réguliers.
- Documenter les politiques et procédures de sécurité.
