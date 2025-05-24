# Erreurs

## Vue d'ensemble

Ce document décrit les erreurs courantes rencontrées dans le projet YourMedia, leurs causes et leurs solutions.

## Infrastructure AWS

### 1. EC2

#### Erreur: Instance non accessible
```
Error: Failed to connect to EC2 instance
```

**Causes:**
- Security Group mal configuré
- Instance non démarrée
- Problème de réseau

**Solutions:**
1. Vérifier les Security Groups
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

2. Vérifier l'état de l'instance
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx
   ```

3. Vérifier les logs système
   ```bash
   aws ec2 get-console-output --instance-id i-xxxxx
   ```

#### Erreur: EBS Volume plein
```
Error: No space left on device
```

**Causes:**
- Logs non nettoyés
- Données temporaires
- Snapshots non supprimés

**Solutions:**
1. Nettoyer les logs
   ```bash
   sudo find /var/log -type f -name "*.log" -mtime +7 -delete
   ```

2. Nettoyer les données temporaires
   ```bash
   sudo rm -rf /tmp/*
   ```

3. Supprimer les anciens snapshots
   ```bash
   aws ec2 describe-snapshots --owner-ids self
   aws ec2 delete-snapshot --snapshot-id snap-xxxxx
   ```

### 2. RDS

#### Erreur: Connexion refusée
```
Error: Access denied for user 'admin'@'%'
```

**Causes:**
- Credentials incorrects
- Security Group mal configuré
- Base de données non accessible

**Solutions:**
1. Vérifier les credentials
   ```bash
   mysql -h yourmedia.cxxxxx.region.rds.amazonaws.com -u admin -p
   ```

2. Vérifier les Security Groups
   ```bash
   aws rds describe-db-instances --db-instance-identifier yourmedia
   ```

3. Vérifier les paramètres de connexion
   ```bash
   aws rds describe-db-parameters --db-parameter-group-name default.mysql8.0
   ```

#### Erreur: Performance dégradée
```
Error: Slow query execution
```

**Causes:**
- Index manquants
- Requêtes non optimisées
- Ressources insuffisantes

**Solutions:**
1. Analyser les requêtes lentes
   ```sql
   SHOW FULL PROCESSLIST;
   ```

2. Optimiser les index
   ```sql
   EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';
   ```

3. Augmenter les ressources
   ```bash
   aws rds modify-db-instance --db-instance-identifier yourmedia --db-instance-class db.t3.small
   ```

## Applications

### 1. Java Spring Boot

#### Erreur: Démarrage échoué
```
Error: Application failed to start
```

**Causes:**
- Port déjà utilisé
- Configuration incorrecte
- Dépendances manquantes

**Solutions:**
1. Vérifier le port
   ```bash
   sudo netstat -tulpn | grep 8080
   ```

2. Vérifier la configuration
   ```bash
   cat application.properties
   ```

3. Vérifier les dépendances
   ```bash
   mvn dependency:tree
   ```

#### Erreur: Mémoire insuffisante
```
Error: OutOfMemoryError: Java heap space
```

**Causes:**
- Heap size trop petit
- Fuite de mémoire
- Charge importante

**Solutions:**
1. Augmenter la heap size
   ```bash
   java -Xmx2g -jar yourmedia.jar
   ```

2. Analyser la mémoire
   ```bash
   jmap -heap <pid>
   ```

3. Optimiser le code
   ```java
   // Utiliser des collections appropriées
   // Éviter les fuites de mémoire
   // Gérer les ressources
   ```

## Monitoring

### 1. Prometheus

#### Erreur: Métriques manquantes
```
Error: No data points
```

**Causes:**
- Scrape config incorrect
- Target inaccessible
- Métriques non exposées

**Solutions:**
1. Vérifier la configuration
   ```bash
   cat scripts/config/prometheus/prometheus.yml
   ```

2. Vérifier les targets
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

3. Vérifier les logs
   ```bash
   docker-compose logs prometheus
   ```

### 2. Grafana

#### Erreur: Datasource inaccessible
```
Error: Failed to query datasource
```

**Causes:**
- Configuration incorrecte
- Service inaccessible
- Problème de réseau

**Solutions:**
1. Vérifier la configuration
   ```bash
   cat scripts/config/grafana/datasources/prometheus.yml
   ```

2. Vérifier l'accès
   ```bash
   curl http://localhost:9090/-/healthy
   ```

3. Vérifier les logs
   ```bash
   docker-compose logs grafana
   ```

### 3. Loki

#### Erreur: Logs non reçus
```
Error: No logs received
```

**Causes:**
- Configuration Promtail incorrecte
- Permissions insuffisantes
- Problème de réseau

**Solutions:**
1. Vérifier la configuration
   ```bash
   cat scripts/config/promtail/promtail-config.yml
   ```

2. Vérifier les permissions
   ```bash
   ls -l /var/log/tomcat/
   ```

3. Vérifier les logs
   ```bash
   docker-compose logs promtail
   ```

### 4. Docker

#### Erreur: Conteneur non démarré
```
Error: Container failed to start
```

**Causes:**
- Configuration incorrecte
- Ressources insuffisantes
- Conflit de ports

**Solutions:**
1. Vérifier la configuration
   ```bash
   cat scripts/ec2-monitoring/docker-compose.yml
   ```

2. Vérifier les ressources
   ```bash
   docker stats
   ```

3. Vérifier les logs
   ```bash
   docker-compose logs
   ```

## Dépannage

### 1. Vérification des Services

```bash
# Vérifier l'état des services
./scripts/ec2-monitoring/check-grafana.sh
./scripts/ec2-monitoring/restart-monitoring.sh

# Vérifier les logs
docker-compose logs

# Vérifier les métriques
curl http://localhost:9090/api/v1/targets
```

### 2. Nettoyage

```bash
# Nettoyer les conteneurs
./scripts/ec2-monitoring/docker-cleanup.sh

# Nettoyer les logs
sudo find /var/log -type f -name "*.log" -mtime +7 -delete

# Nettoyer le cache
sudo rm -rf /tmp/*
```

### 3. Redémarrage

```bash
# Redémarrer les services
./scripts/ec2-monitoring/restart-monitoring.sh

# Redémarrer Docker
sudo systemctl restart docker

# Redémarrer les conteneurs
docker-compose down
docker-compose up -d
```

## Maintenance

### 1. Mise à Jour

```bash
# Mettre à jour les images
docker-compose pull

# Mettre à jour les configurations
./scripts/ec2-monitoring/setup-monitoring-complete.sh

# Mettre à jour les dashboards
./scripts/ec2-monitoring/copy-dashboards.sh
```

### 2. Sauvegarde

```bash
# Sauvegarder les configurations
tar -czf config-backup.tar.gz scripts/config/

# Sauvegarder les données
docker-compose exec prometheus promtool tsdb backup /backup

# Sauvegarder les dashboards
./scripts/ec2-monitoring/copy-dashboards.sh
```

### 3. Restauration

```bash
# Restaurer les configurations
tar -xzf config-backup.tar.gz

# Restaurer les données
docker-compose exec prometheus promtool tsdb restore /backup

# Restaurer les dashboards
./scripts/ec2-monitoring/copy-dashboards.sh
```

## Ressources

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Documentation Loki](https://grafana.com/docs/loki/latest/)
- [Documentation Docker](https://docs.docker.com/) 