# Guide Docker pour YourMedia

Ce document centralise toutes les informations relatives à Docker dans le projet YourMedia.

## 1. Installation de Docker

### 1.1. Installation sur Amazon Linux 2023

```bash
# Mettre à jour le système
sudo dnf update -y

# Installer Docker
sudo dnf install -y docker

# Démarrer et activer le service Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter l'utilisateur ec2-user au groupe docker
sudo usermod -aG docker ec2-user
```

Pour plus de détails, consultez l'ancien document [DOCKER-INSTALLATION-AL2023.md](./archive/DOCKER-INSTALLATION-AL2023.md).

### 1.2. Résolution des problèmes d'installation

Si vous rencontrez des problèmes lors de l'installation de Docker, voici quelques solutions courantes :

- **Problème de permissions** : Assurez-vous que l'utilisateur est dans le groupe docker
- **Problème de démarrage du service** : Vérifiez les logs avec `sudo journalctl -u docker`
- **Problème de réseau** : Vérifiez la configuration réseau avec `docker network ls`

Pour plus de détails, consultez l'ancien document [DOCKER-INSTALLATION-FIXES.md](./archive/DOCKER-INSTALLATION-FIXES.md).

## 2. Gestion des conteneurs Docker

### 2.1. Commandes de base

```bash
# Lister les conteneurs en cours d'exécution
docker ps

# Lister tous les conteneurs (y compris ceux arrêtés)
docker ps -a

# Démarrer un conteneur
docker start <container_id>

# Arrêter un conteneur
docker stop <container_id>

# Supprimer un conteneur
docker rm <container_id>
```

### 2.2. Utilisation de docker-compose

Le projet utilise docker-compose pour orchestrer les conteneurs. Voici les commandes principales :

```bash
# Démarrer tous les services définis dans docker-compose.yml
docker-compose up -d

# Arrêter tous les services
docker-compose down

# Voir les logs
docker-compose logs -f
```

### 2.3. Script docker-manager.sh

Le projet inclut un script utilitaire `docker-manager.sh` qui simplifie la gestion des conteneurs Docker :

```bash
# Déployer les conteneurs de monitoring
./scripts/utils/docker-manager.sh deploy monitoring

# Déployer les conteneurs d'application
./scripts/utils/docker-manager.sh deploy mobile

# Nettoyer les conteneurs
./scripts/utils/docker-manager.sh cleanup
```

Pour plus de détails, consultez l'ancien document [DOCKER-MANAGEMENT.md](./archive/DOCKER-MANAGEMENT.md).

## 3. Variables Docker standardisées

### 3.1. Variables standardisées

Les variables suivantes sont considérées comme les variables standard pour Docker Hub :

| Variable | Description | Utilisation |
|----------|-------------|-------------|
| `DOCKERHUB_USERNAME` | Nom d'utilisateur Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_TOKEN` | Token d'authentification Docker Hub | Authentification auprès de Docker Hub |
| `DOCKERHUB_REPO` | Nom du dépôt Docker Hub | Référence aux images Docker |

### 3.2. Utilisation dans les scripts shell

```bash
# Connexion à Docker Hub
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Construction et publication d'une image
docker build -t $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest .
docker push $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest
```

Pour plus de détails, consultez l'ancien document [DOCKER-VARIABLES-STANDARDISATION.md](./archive/DOCKER-VARIABLES-STANDARDISATION.md).

## 4. Sécurité Docker

### 4.1. Bonnes pratiques de sécurité

- Utilisez des images officielles et à jour
- Scannez régulièrement vos images avec Trivy
- Limitez les privilèges des conteneurs
- Utilisez des secrets sécurisés pour l'authentification
- Ne stockez pas de secrets dans les images Docker

### 4.2. Scan de sécurité avec Trivy

Le projet utilise Trivy pour scanner les images Docker à la recherche de vulnérabilités :

```bash
# Scanner une image Docker
trivy image $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest

# Scanner avec des options spécifiques
trivy image --severity HIGH,CRITICAL --ignore-unfixed $DOCKERHUB_USERNAME/$DOCKERHUB_REPO:latest
```

Pour plus de détails, consultez l'ancien document [DOCKER-SECURITY-GUIDE.md](./archive/DOCKER-SECURITY-GUIDE.md).

## 5. Dépannage Docker

### 5.1. Problèmes courants et solutions

- **Conteneur qui s'arrête immédiatement** : Vérifiez les logs avec `docker logs <container_id>`
- **Problèmes de réseau** : Vérifiez la configuration réseau avec `docker network inspect bridge`
- **Problèmes de stockage** : Vérifiez l'espace disque avec `df -h` et `docker system df`

### 5.2. Commandes de diagnostic

```bash
# Voir les logs d'un conteneur
docker logs <container_id>

# Exécuter une commande dans un conteneur en cours d'exécution
docker exec -it <container_id> /bin/bash

# Inspecter un conteneur
docker inspect <container_id>

# Voir les statistiques d'utilisation des ressources
docker stats
```

Pour plus de détails, consultez l'ancien document [DOCKER-TROUBLESHOOTING.md](./archive/DOCKER-TROUBLESHOOTING.md).

## 6. Optimisations pour le free tier AWS

### 6.1. Limites de ressources

Les limites de ressources des conteneurs Docker ont été optimisées pour s'adapter aux contraintes du Free Tier :

- Prometheus : 256 Mo de RAM (au lieu de 512 Mo)
- Grafana : 256 Mo de RAM (au lieu de 512 Mo)
- MySQL Exporter : 128 Mo de RAM (au lieu de 256 Mo)
- Node Exporter : 128 Mo de RAM
- Loki : 256 Mo de RAM (au lieu de 512 Mo)
- Promtail : 128 Mo de RAM (au lieu de 256 Mo)

Pour plus de détails, consultez l'ancien document [OPTIMISATIONS-FREE-TIER.md](./archive/OPTIMISATIONS-FREE-TIER.md).
