# Corrections de l'installation de Docker sur Amazon Linux 2023

Ce document décrit les corrections apportées à l'installation de Docker sur Amazon Linux 2023 et à la création des fichiers de configuration.

## Problèmes identifiés

### 1. Installation de Docker

Le script d'installation de Docker essayait d'utiliser le dépôt Docker pour CentOS, qui n'est pas compatible avec Amazon Linux 2023. Cela provoquait l'erreur suivante :

```
Errors during downloading metadata for repository 'docker-ce-stable':
  - Status code: 404 for https://download.docker.com/linux/centos/2023.7.20250414/x86_64/stable/repodata/repomd.xml
Error: Failed to download metadata for repo 'docker-ce-stable': Cannot download repomd.xml: Cannot download repodata/repomd.xml: All mirrors were tried
```

De plus, l'installation de curl provoquait des conflits de paquets :

```
Error:
 Problem: problem with installed package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64
  - package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64 from @System conflicts with curl provided by curl-7.87.0-2.amzn2023.0.2.x86_64 from amazonlinux
  ...
```

### 2. Création des fichiers de configuration

La création des fichiers `docker-compose.yml` et `prometheus.yml` échouait avec des erreurs de syntaxe :

```
/opt/monitoring/setup.sh: line 169: version:: command not found
/opt/monitoring/setup.sh: line 171: services:: command not found
/opt/monitoring/setup.sh: line 172: prometheus:: command not found
...
```

## Solutions mises en œuvre

### 1. Installation de Docker

Nous avons modifié le script `install-docker.sh` pour utiliser le paquet Docker natif d'Amazon Linux 2023 au lieu du script get-docker.sh :

```bash
log "Installation de Docker natif pour Amazon Linux 2023"
dnf install -y docker || error_exit "Impossible d'installer Docker"
```

Cette approche présente plusieurs avantages :
- Elle évite les conflits de paquets avec curl
- Elle utilise le paquet Docker officiel d'Amazon Linux 2023, qui est optimisé pour cette distribution
- Elle est plus simple et plus fiable

### 2. Création des fichiers de configuration

Nous avons corrigé la création des fichiers `docker-compose.yml` et `prometheus.yml` en utilisant la syntaxe correcte pour les here-documents :

```bash
cat > /opt/monitoring/docker-compose.yml << 'EOF'
...
EOF
```

Les principales modifications sont :
- Utilisation de `cat` directement au lieu de `sudo bash -c 'cat ...'`
- Utilisation de `'EOF'` au lieu de `"EOL"` pour éviter l'interprétation des variables dans le here-document

## Comment tester les modifications

1. Exécutez le script `setup.sh` sur une instance Amazon Linux 2023 :
   ```bash
   sudo /opt/monitoring/setup.sh
   ```

2. Vérifiez que Docker est correctement installé :
   ```bash
   docker --version
   ```

3. Vérifiez que les conteneurs sont en cours d'exécution :
   ```bash
   docker ps
   ```

## Conclusion

Ces modifications garantissent que Docker est correctement installé sur Amazon Linux 2023 et que les fichiers de configuration sont correctement créés. Cela permet de déployer les conteneurs de surveillance (Prometheus, Grafana, etc.) sans erreur.

Si vous rencontrez encore des problèmes, vous pouvez installer Docker manuellement avec la commande suivante :

```bash
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
```
