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

### 2. React

#### Erreur: Build échoué
```
Error: Failed to compile
```

**Causes:**
- Dépendances incompatibles
- Syntaxe incorrecte
- Configuration webpack

**Solutions:**
1. Nettoyer le cache
   ```bash
   npm cache clean --force
   rm -rf node_modules
   npm install
   ```

2. Vérifier la syntaxe
   ```bash
   npm run lint
   ```

3. Vérifier la configuration
   ```bash
   cat webpack.config.js
   ```

#### Erreur: Performance dégradée
```
Error: Slow rendering
```

**Causes:**
- Rendu inutile
- Composants lourds
- État mal géré

**Solutions:**
1. Optimiser les rendus
   ```javascript
   // Utiliser React.memo
   // Implémenter useMemo
   // Gérer les props
   ```

2. Analyser les performances
   ```javascript
   // Utiliser React Profiler
   // Mesurer les rendus
   // Identifier les goulots d'étranglement
   ```

3. Optimiser les assets
   ```bash
   npm run build -- --optimize
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
   ```yaml
   scrape_configs:
     - job_name: 'java'
       static_configs:
         - targets: ['localhost:8080']
   ```

2. Vérifier l'accès
   ```bash
   curl http://localhost:8080/actuator/prometheus
   ```

3. Vérifier les métriques
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

#### Erreur: Stockage plein
```
Error: Storage full
```

**Causes:**
- Rétention trop longue
- Données volumineuses
- Disque plein

**Solutions:**
1. Ajuster la rétention
   ```yaml
   storage:
     tsdb:
       retention:
         time: 15d
   ```

2. Nettoyer les données
   ```bash
   prometheus --storage.tsdb.retention.time=15d
   ```

3. Augmenter le stockage
   ```bash
   aws ec2 modify-volume --volume-id vol-xxxxx --size 100
   ```

### 2. Grafana

#### Erreur: Connexion refusée
```
Error: Access denied
```

**Causes:**
- Credentials incorrects
- Permissions insuffisantes
- Configuration incorrecte

**Solutions:**
1. Vérifier les credentials
   ```ini
   [security]
   admin_user = admin
   admin_password = changeme
   ```

2. Vérifier les permissions
   ```bash
   ls -l /var/lib/grafana
   ```

3. Vérifier la configuration
   ```bash
   cat grafana.ini
   ```

#### Erreur: Dashboard non chargé
```
Error: Failed to load dashboard
```

**Causes:**
- JSON invalide
- Datasource manquante
- Permissions insuffisantes

**Solutions:**
1. Vérifier le JSON
   ```bash
   cat dashboard.json | jq
   ```

2. Vérifier les datasources
   ```bash
   curl http://localhost:3000/api/datasources
   ```

3. Vérifier les permissions
   ```bash
   curl http://localhost:3000/api/dashboards/uid/xxxxx
   ```

## Base de Données

### 1. MySQL

#### Erreur: Connexion refusée
```
Error: Can't connect to MySQL server
```

**Causes:**
- Service arrêté
- Port bloqué
- Credentials incorrects

**Solutions:**
1. Vérifier le service
   ```bash
   sudo systemctl status mysql
   ```

2. Vérifier le port
   ```bash
   sudo netstat -tulpn | grep 3306
   ```

3. Vérifier les credentials
   ```bash
   mysql -u root -p
   ```

#### Erreur: Requête lente
```
Error: Query taking too long
```

**Causes:**
- Index manquant
- Requête non optimisée
- Données volumineuses

**Solutions:**
1. Analyser la requête
   ```sql
   EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';
   ```

2. Optimiser les index
   ```sql
   CREATE INDEX idx_email ON users(email);
   ```

3. Optimiser la requête
   ```sql
   SELECT id, email FROM users WHERE email = 'test@example.com';
   ```

### 2. Redis

#### Erreur: Mémoire pleine
```
Error: OOM command not allowed
```

**Causes:**
- Données volumineuses
- TTL manquant
- Configuration incorrecte

**Solutions:**
1. Vérifier la mémoire
   ```bash
   redis-cli info memory
   ```

2. Configurer le TTL
   ```bash
   redis-cli CONFIG SET maxmemory-policy allkeys-lru
   ```

3. Nettoyer les données
   ```bash
   redis-cli FLUSHALL
   ```

#### Erreur: Connexion perdue
```
Error: Connection reset by peer
```

**Causes:**
- Timeout
- Réseau instable
- Configuration incorrecte

**Solutions:**
1. Ajuster le timeout
   ```bash
   redis-cli CONFIG SET timeout 300
   ```

2. Vérifier le réseau
   ```bash
   ping redis-server
   ```

3. Vérifier la configuration
   ```bash
   redis-cli CONFIG GET *
   ```

## CI/CD

### 1. GitHub Actions

#### Erreur: Workflow échoué
```
Error: Workflow failed
```

**Causes:**
- Tests échoués
- Build échoué
- Déploiement échoué

**Solutions:**
1. Vérifier les tests
   ```bash
   npm test
   mvn test
   ```

2. Vérifier le build
   ```bash
   npm run build
   mvn clean install
   ```

3. Vérifier le déploiement
   ```bash
   aws ecs describe-services --cluster yourmedia --services yourmedia-service
   ```

#### Erreur: Secrets manquants
```
Error: Secret not found
```

**Causes:**
- Secret non configuré
- Permission insuffisante
- Nom incorrect

**Solutions:**
1. Vérifier les secrets
   ```bash
   aws secretsmanager list-secrets
   ```

2. Vérifier les permissions
   ```bash
   aws iam get-user-policy --user-name github-actions --policy-name secrets-access
   ```

3. Vérifier les noms
   ```yaml
   env:
     AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
   ```

### 2. Docker

#### Erreur: Build échoué
```
Error: Failed to build image
```

**Causes:**
- Dockerfile invalide
- Dépendances manquantes
- Ressources insuffisantes

**Solutions:**
1. Vérifier le Dockerfile
   ```bash
   docker build -t yourmedia .
   ```

2. Vérifier les dépendances
   ```bash
   docker-compose build
   ```

3. Vérifier les ressources
   ```bash
   docker system df
   ```

#### Erreur: Container arrêté
```
Error: Container exited with code 1
```

**Causes:**
- Application crash
- Ressources insuffisantes
- Configuration incorrecte

**Solutions:**
1. Vérifier les logs
   ```bash
   docker logs container-name
   ```

2. Vérifier les ressources
   ```bash
   docker stats container-name
   ```

3. Vérifier la configuration
   ```bash
   docker inspect container-name
   ``` 