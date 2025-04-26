# Exigences en matière de droits pour les scripts

Ce document décrit les exigences en matière de droits pour les scripts du projet YourMédia, ainsi que les bonnes pratiques à suivre pour leur exécution.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Scripts nécessitant des privilèges sudo](#scripts-nécessitant-des-privilèges-sudo)
3. [Vérification automatique des droits](#vérification-automatique-des-droits)
4. [Bonnes pratiques](#bonnes-pratiques)
5. [Résolution des problèmes courants](#résolution-des-problèmes-courants)

## Vue d'ensemble

La plupart des scripts du projet YourMédia nécessitent des privilèges sudo pour fonctionner correctement, car ils effectuent des opérations qui nécessitent des droits d'administrateur, telles que :

- Installation de paquets système
- Gestion des services système
- Manipulation des conteneurs Docker
- Modification des fichiers système
- Gestion des permissions de fichiers

Tous les scripts ont été conçus pour vérifier automatiquement si l'utilisateur dispose des privilèges nécessaires et afficher un message d'erreur approprié si ce n'est pas le cas.

## Scripts nécessitant des privilèges sudo

### Scripts d'installation

| Script | Description | Exigences en matière de droits |
|--------|-------------|--------------------------------|
| `scripts/ec2-monitoring/install-docker.sh` | Installation de Docker sur Amazon Linux 2023 | Doit être exécuté avec sudo ou en tant que root |
| `scripts/ec2-java-tomcat/install_java_tomcat.sh` | Installation de Java et Tomcat | Doit être exécuté avec sudo ou en tant que root |

### Scripts de configuration

| Script | Description | Exigences en matière de droits |
|--------|-------------|--------------------------------|
| `scripts/ec2-monitoring/setup.sh` | Configuration des conteneurs Docker pour le monitoring | Doit être exécuté avec sudo ou en tant que root |
| `scripts/ec2-monitoring/fix_permissions.sh` | Correction des permissions pour Grafana et Prometheus | Doit être exécuté avec sudo ou en tant que root |

### Scripts de déploiement

| Script | Description | Exigences en matière de droits |
|--------|-------------|--------------------------------|
| `scripts/ec2-java-tomcat/deploy-war.sh` | Déploiement d'un fichier WAR dans Tomcat | Doit être exécuté avec sudo ou en tant que root |
| `scripts/docker/docker-manager.sh` | Gestion des images Docker et des conteneurs | Nécessite sudo pour certaines opérations |

## Vérification automatique des droits

Tous les scripts du projet vérifient automatiquement si l'utilisateur dispose des privilèges nécessaires. Voici comment cette vérification est effectuée :

### Vérification simple

```bash
# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERREUR] Ce script doit être exécuté avec sudo"
    echo "Exemple: sudo $0 $*"
    exit 1
fi
```

### Vérification avancée avec tentative d'obtention des droits sudo

```bash
# Vérification des droits sudo
if [ "$(id -u)" -ne 0 ]; then
    log "Ce script nécessite des privilèges sudo."
    if sudo -n true 2>/dev/null; then
        log "Privilèges sudo disponibles sans mot de passe."
    else
        log "Tentative d'obtention des privilèges sudo..."
        if ! sudo -v; then
            error_exit "Impossible d'obtenir les privilèges sudo. Veuillez exécuter ce script avec sudo ou en tant que root."
        fi
        log "Privilèges sudo obtenus avec succès."
    fi
fi
```

### Relancement automatique avec sudo

Certains scripts tentent de se relancer automatiquement avec sudo si l'utilisateur ne dispose pas des privilèges nécessaires :

```bash
# Vérifier si l'utilisateur a les droits sudo
if [ "$(id -u)" -ne 0 ]; then
    error "Ce script doit être exécuté avec sudo"
    error "Exemple: sudo $0 $*"
    
    # Tentative d'obtention des droits sudo
    info "Tentative d'obtention des privilèges sudo..."
    if sudo -n true 2>/dev/null; then
        info "Relancement du script avec sudo..."
        exec sudo "$0" "$@"
    else
        error "Impossible d'obtenir les privilèges sudo automatiquement."
        exit 1
    fi
fi
```

## Bonnes pratiques

### Exécution des scripts

1. **Toujours utiliser sudo** pour exécuter les scripts qui nécessitent des privilèges élevés :
   ```bash
   sudo ./script.sh
   ```

2. **Vérifier les messages d'erreur** si un script échoue, car ils peuvent indiquer un problème de droits.

3. **Ne pas exécuter les scripts en tant que root** directement, mais plutôt utiliser sudo.

### Modification des scripts

1. **Toujours inclure une vérification des droits** au début du script.

2. **Documenter les exigences en matière de droits** dans les commentaires au début du script.

3. **Utiliser des fonctions d'erreur** pour afficher des messages clairs en cas de problème de droits.

4. **Préférer l'utilisation de sudo pour les commandes individuelles** plutôt que d'exécuter l'ensemble du script avec sudo.

## Résolution des problèmes courants

### Erreur "Permission denied"

Si vous rencontrez une erreur "Permission denied" lors de l'exécution d'un script, assurez-vous que :

1. Le script est exécutable :
   ```bash
   chmod +x script.sh
   ```

2. Vous exécutez le script avec sudo :
   ```bash
   sudo ./script.sh
   ```

### Erreur "sudo: command not found"

Si vous rencontrez une erreur "sudo: command not found", cela signifie que sudo n'est pas installé sur votre système. Installez-le avec :

```bash
apt-get update && apt-get install -y sudo  # Pour Debian/Ubuntu
yum install -y sudo                        # Pour CentOS/RHEL/Amazon Linux
```

### Erreur "Sorry, user XXX is not allowed to execute YYY as root"

Si vous rencontrez cette erreur, cela signifie que votre utilisateur n'est pas autorisé à exécuter la commande avec sudo. Ajoutez votre utilisateur au groupe sudo :

```bash
usermod -aG sudo username  # Pour Debian/Ubuntu
usermod -aG wheel username # Pour CentOS/RHEL/Amazon Linux
```

Puis déconnectez-vous et reconnectez-vous pour que les changements prennent effet.

### Erreur "Docker command not found" même avec sudo

Si vous rencontrez cette erreur, cela signifie que Docker n'est pas installé ou que le chemin vers Docker n'est pas dans le PATH de l'utilisateur root. Exécutez :

```bash
sudo ./scripts/ec2-monitoring/install-docker.sh
```

pour installer Docker correctement.
