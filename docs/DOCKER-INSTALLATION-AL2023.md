# Installation de Docker sur Amazon Linux 2023

Ce document décrit la méthode d'installation de Docker sur Amazon Linux 2023 utilisée dans le projet YourMédia.

## Problème

L'installation de Docker sur Amazon Linux 2023 échouait car le script essayait d'utiliser le dépôt Docker pour CentOS, qui n'est pas compatible avec la version spécifique d'Amazon Linux 2023 utilisée (2023.7.20250414).

Le message d'erreur suivant était affiché :

```
Errors during downloading metadata for repository 'docker-ce-stable':
  - Status code: 404 for https://download.docker.com/linux/centos/2023.7.20250414/x86_64/stable/repodata/repomd.xml
Error: Failed to download metadata for repo 'docker-ce-stable': Cannot download repomd.xml: Cannot download repodata/repomd.xml: All mirrors were tried
```

## Solution

La solution consiste à utiliser le script d'installation officiel de Docker (`get-docker.sh`) au lieu d'essayer d'ajouter le dépôt Docker pour CentOS.

### Méthode d'installation

1. Mettre à jour les paquets
   ```bash
   sudo dnf update -y
   ```

2. Installer les paquets nécessaires
   ```bash
   sudo dnf install -y tar gzip curl
   ```

3. Télécharger le script d'installation de Docker
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   ```

4. Exécuter le script d'installation de Docker
   ```bash
   sudo sh get-docker.sh
   ```

5. Supprimer le script d'installation
   ```bash
   rm -f get-docker.sh
   ```

6. Démarrer et activer le service Docker
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

7. Ajouter l'utilisateur ec2-user au groupe docker
   ```bash
   sudo usermod -aG docker ec2-user
   ```

## Modifications apportées

### 1. Script `install-docker.sh`

Le script `install-docker.sh` a été modifié pour utiliser le script d'installation officiel de Docker (`get-docker.sh`) au lieu d'essayer d'ajouter le dépôt Docker pour CentOS.

```bash
# Installation pour Amazon Linux 2023
log "Système détecté: Amazon Linux 2023"

log "Mise à jour des paquets"
dnf update -y || error_exit "Impossible de mettre à jour les paquets"

log "Installation des paquets nécessaires"
dnf install -y tar gzip curl || error_exit "Impossible d'installer les paquets nécessaires"

log "Téléchargement du script d'installation de Docker"
curl -fsSL https://get.docker.com -o get-docker.sh || error_exit "Impossible de télécharger le script d'installation de Docker"

log "Exécution du script d'installation de Docker"
sh get-docker.sh || error_exit "Impossible d'exécuter le script d'installation de Docker"

# Supprimer le script d'installation
rm -f get-docker.sh
```

### 2. Script `setup.sh`

Le script `setup.sh` a également été modifié pour utiliser la même méthode d'installation de Docker si le script `install-docker.sh` n'est pas disponible.

```bash
# Installation pour Amazon Linux 2023 avec le script get-docker.sh
log "Système détecté: Amazon Linux 2023"
log "Installation des paquets nécessaires"
sudo dnf install -y tar gzip curl

log "Téléchargement du script d'installation de Docker"
curl -fsSL https://get.docker.com -o get-docker.sh

log "Exécution du script d'installation de Docker"
sudo sh get-docker.sh

# Supprimer le script d'installation
rm -f get-docker.sh

log "Démarrage et activation du service Docker"
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
```

## Vérification de l'installation

Pour vérifier que Docker est correctement installé, exécutez la commande suivante :

```bash
docker --version
```

Pour vérifier que le service Docker est en cours d'exécution, exécutez la commande suivante :

```bash
sudo systemctl status docker
```

Pour vérifier que l'utilisateur ec2-user est dans le groupe docker, exécutez la commande suivante :

```bash
groups ec2-user
```

## Conclusion

Cette méthode d'installation de Docker sur Amazon Linux 2023 est plus robuste et devrait fonctionner sur toutes les versions d'Amazon Linux 2023, y compris les versions futures.
