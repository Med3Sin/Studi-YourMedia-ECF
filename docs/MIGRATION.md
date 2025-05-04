# Guide de Migration - YourMedia

Ce document centralise toutes les informations relatives aux migrations et mises à jour dans le projet YourMedia.

## Table des matières

1. [Migration vers Amazon Linux 2023](#1-migration-vers-amazon-linux-2023)
   - [Vue d'ensemble](#11-vue-densemble)
   - [Changements majeurs](#12-changements-majeurs)
   - [Étapes de migration](#13-étapes-de-migration)
2. [Installation de Docker sur Amazon Linux 2023](#2-installation-de-docker-sur-amazon-linux-2023)
   - [Méthode recommandée](#21-méthode-recommandée)
   - [Résolution des problèmes courants](#22-résolution-des-problèmes-courants)
   - [Vérification de l'installation](#23-vérification-de-linstallation)
3. [Mises à jour des applications](#3-mises-à-jour-des-applications)
   - [Backend Java](#31-backend-java)
   - [Frontend React](#32-frontend-react)
4. [Rollback en cas de problème](#4-rollback-en-cas-de-problème)

## 1. Migration vers Amazon Linux 2023

### 1.1. Vue d'ensemble

Amazon Linux 2023 est la nouvelle génération d'Amazon Linux, offrant des améliorations significatives par rapport à Amazon Linux 2 :

- Mises à jour de sécurité plus fréquentes
- Versions plus récentes des paquets
- Support à long terme (5 ans)
- Meilleure compatibilité avec les applications modernes
- Performances améliorées

Cette migration permet de bénéficier de ces avantages tout en maintenant la compatibilité avec l'infrastructure existante.

### 1.2. Changements majeurs

#### Détection automatique des AMI

Les modules Terraform ont été mis à jour pour détecter automatiquement les dernières AMI Amazon Linux 2023 :

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

#### Gestion des paquets avec DNF

Amazon Linux 2023 utilise DNF comme gestionnaire de paquets au lieu de YUM. Tous les scripts ont été mis à jour pour utiliser DNF :

```bash
# Ancienne commande (Amazon Linux 2)
sudo yum update -y
sudo yum install -y package-name

# Nouvelle commande (Amazon Linux 2023)
sudo dnf update -y
sudo dnf install -y package-name
```

Les modifications incluent :
- Remplacement de `yum` par `dnf` dans tous les scripts
- Remplacement de `yum-utils` par `dnf-utils`
- Remplacement de `yum-config-manager` par `dnf config-manager`

#### Suppression de amazon-linux-extras

La fonctionnalité `amazon-linux-extras` n'existe plus dans Amazon Linux 2023. Les scripts ont été mis à jour pour installer directement les paquets nécessaires :

```bash
# Ancienne méthode (Amazon Linux 2)
sudo amazon-linux-extras install -y java-openjdk11

# Nouvelle méthode (Amazon Linux 2023)
sudo dnf install -y java-17-amazon-corretto-devel
```

### 1.3. Étapes de migration

1. **Mise à jour des modules Terraform** :
   - Modifier les filtres de recherche d'AMI pour utiliser `al2023-ami-2023*-x86_64`
   - Mettre à jour les variables et les descriptions

2. **Adaptation des scripts d'installation** :
   - Remplacer `yum` par `dnf`
   - Supprimer les références à `amazon-linux-extras`
   - Mettre à jour les chemins et les commandes

3. **Mise à jour des workflows GitHub Actions** :
   - Mettre à jour les workflows pour utiliser les nouvelles AMI
   - Mettre à jour les commandes d'installation des dépendances

4. **Tests et validation** :
   - Déployer l'infrastructure avec les nouvelles AMI
   - Vérifier l'installation des applications
   - Tester le fonctionnement des applications

## 2. Installation de Docker sur Amazon Linux 2023

### 2.1. Méthode recommandée

La méthode recommandée pour installer Docker sur Amazon Linux 2023 est d'utiliser le paquet Docker natif :

```bash
# Mettre à jour les paquets
sudo dnf update -y

# Installer Docker
sudo dnf install -y docker

# Démarrer et activer le service Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter l'utilisateur ec2-user au groupe docker
sudo usermod -aG docker ec2-user
```

Cette méthode est plus simple et plus fiable que d'utiliser le script d'installation officiel de Docker (`get-docker.sh`).

### 2.2. Résolution des problèmes courants

#### Problème : Erreur 404 lors de l'ajout du dépôt Docker

**Symptôme :**
```
Errors during downloading metadata for repository 'docker-ce-stable':
  - Status code: 404 for https://download.docker.com/linux/centos/2023.7.20250414/x86_64/stable/repodata/repomd.xml
```

**Solution :**
Utiliser le paquet Docker natif d'Amazon Linux 2023 au lieu d'essayer d'ajouter le dépôt Docker pour CentOS.

#### Problème : Conflits de paquets avec curl

**Symptôme :**
```
Error:
 Problem: problem with installed package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64
  - package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64 from @System conflicts with curl provided by curl-7.87.0-2.amzn2023.0.2.x86_64 from amazonlinux
```

**Solution :**
Utiliser le paquet Docker natif d'Amazon Linux 2023 qui ne nécessite pas l'installation de curl.

#### Problème : Erreurs de syntaxe lors de la création des fichiers de configuration

**Symptôme :**
```
/opt/monitoring/setup.sh: line 169: version:: command not found
/opt/monitoring/setup.sh: line 171: services:: command not found
```

**Solution :**
Utiliser la syntaxe correcte pour les here-documents :

```bash
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3'
services:
  ...
EOF
```

### 2.3. Vérification de l'installation

Pour vérifier que Docker est correctement installé :

```bash
# Vérifier la version de Docker
docker --version

# Vérifier que le service Docker est en cours d'exécution
sudo systemctl status docker

# Vérifier que l'utilisateur ec2-user est dans le groupe docker
groups ec2-user
```

## 3. Mises à jour des applications

### 3.1. Backend Java

Le backend Java a été mis à jour pour utiliser Java 17 au lieu de Java 11 :

```bash
# Installer Java 17
sudo dnf install -y java-17-amazon-corretto-devel

# Vérifier la version de Java
java -version
```

Les modifications incluent :
- Mise à jour du fichier `pom.xml` pour utiliser Java 17
- Mise à jour des dépendances Spring Boot
- Adaptation du code pour utiliser les fonctionnalités de Java 17

### 3.2. Frontend React

Le frontend React a été mis à jour pour utiliser les dernières versions des dépendances :

```bash
# Mettre à jour les dépendances
npm update

# Vérifier les vulnérabilités
npm audit fix
```

Les modifications incluent :
- Mise à jour de React et React DOM
- Mise à jour des dépendances de développement
- Adaptation du code pour utiliser les nouvelles API

## 4. Rollback en cas de problème

En cas de problème avec Amazon Linux 2023, il est possible de revenir à Amazon Linux 2 :

1. **Modules Terraform** :
   - Modifier les filtres de recherche d'AMI pour utiliser `amzn2-ami-hvm-*-x86_64-gp2`
   - Mettre à jour les variables et les descriptions

2. **Scripts** :
   - Remplacer `dnf` par `yum` dans tous les scripts
   - Réintroduire les références à `amazon-linux-extras`
   - Mettre à jour les chemins et les commandes

3. **Workflows GitHub Actions** :
   - Mettre à jour les workflows pour utiliser les anciennes AMI
   - Mettre à jour les commandes d'installation des dépendances

Il est recommandé de conserver une copie des fichiers originaux avant la migration pour faciliter le rollback si nécessaire.
