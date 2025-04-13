# Configuration des permissions pour Grafana et Prometheus

Ce document explique comment les permissions sont configurées pour les conteneurs Grafana et Prometheus sur l'instance EC2 de monitoring.

## Problèmes courants

Les conteneurs Docker pour Grafana et Prometheus peuvent rencontrer des problèmes de permissions lorsqu'ils tentent d'écrire dans les volumes montés. Ces problèmes se manifestent par :

1. **Pour Prometheus** : Erreur `open /prometheus/queries.active: permission denied`
2. **Pour Grafana** : Erreur `GF_PATHS_DATA='/var/lib/grafana' is not writable`

## Solution automatisée

Un script de correction des permissions (`fix_permissions.sh`) est automatiquement exécuté lors du provisionnement de l'instance EC2 de monitoring. Ce script :

1. Arrête les conteneurs existants s'ils sont en cours d'exécution
2. Nettoie les répertoires de données
3. Corrige les permissions des répertoires :
   - `/opt/monitoring/prometheus-data` : propriétaire 65534:65534 (utilisateur Prometheus)
   - `/opt/monitoring/grafana-data` : propriétaire 472:472 (utilisateur Grafana)
4. Crée un fichier `docker-compose.yml` avec les utilisateurs spécifiés
5. Redémarre les conteneurs

## Configuration du groupe de sécurité

Les ports suivants sont ouverts dans le groupe de sécurité de l'instance EC2 de monitoring :

- **SSH (22)** : Permet de se connecter à l'instance via SSH
- **Grafana (3000)** : Permet d'accéder à l'interface web de Grafana
- **Prometheus (9090)** : Permet d'accéder à l'interface web de Prometheus

## Accès aux interfaces web

Une fois l'instance EC2 de monitoring provisionnée, vous pouvez accéder aux interfaces web :

- **Prometheus** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:9090
- **Grafana** : http://<IP_PUBLIQUE_DE_L_INSTANCE>:3000

Pour Grafana, utilisez les identifiants suivants :
- Nom d'utilisateur : `admin`
- Mot de passe : `admin`

## Dépannage manuel

Si vous rencontrez toujours des problèmes, vous pouvez exécuter manuellement le script de correction des permissions :

```bash
# Se connecter à l'instance EC2
ssh ec2-user@<IP_PUBLIQUE_DE_L_INSTANCE>

# Exécuter le script de correction des permissions
sudo /opt/monitoring/fix_permissions.sh
```

Vous pouvez également vérifier les logs des conteneurs pour diagnostiquer les problèmes :

```bash
docker logs prometheus
docker logs grafana
```
