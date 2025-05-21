# Guide de Dépannage

## Vue d'ensemble

Ce document fournit des solutions aux problèmes courants rencontrés dans le projet YourMedia, couvrant l'infrastructure, les applications et le monitoring.

## Infrastructure AWS

### 1. Problèmes de Connexion EC2

#### Symptômes
- Impossible de se connecter via SSH
- Timeout des connexions
- Erreurs de permission

#### Solutions
1. Vérifier les Security Groups
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

2. Vérifier les clés SSH
   ```bash
   ssh -i yourmedia-key.pem -v ec2-user@your-instance-ip
   ```

3. Vérifier l'état de l'instance
   ```bash
   aws ec2 describe-instances --instance-ids i-xxxxx
   ```

### 2. Problèmes RDS

#### Symptômes
- Erreurs de connexion à la base de données
- Performances lentes
- Erreurs de stockage

#### Solutions
1. Vérifier les paramètres de connexion
   ```bash
   mysql -h yourmedia-db.xxxxx.region.rds.amazonaws.com -u admin -p
   ```

2. Vérifier l'espace disque
   ```sql
   SELECT table_schema, ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
   FROM information_schema.tables
   GROUP BY table_schema;
   ```

3. Vérifier les logs RDS
   ```bash
   aws rds describe-db-log-files --db-instance-identifier yourmedia-db
   ```

## Applications

### 1. Problèmes Java

#### Symptômes
- Erreurs 500
- Timeouts
- Fuites mémoire

#### Solutions
1. Vérifier les logs Tomcat
   ```bash
   tail -f /var/log/tomcat/catalina.out
   ```

2. Vérifier la mémoire JVM
   ```bash
   jps -l
   jmap -heap <pid>
   ```

3. Vérifier les threads
   ```bash
   jstack <pid>
   ```

### 2. Problèmes React

#### Symptômes
- Erreurs de build
- Problèmes de rendu
- Erreurs API

#### Solutions
1. Vérifier les logs de build
   ```bash
   npm run build --verbose
   ```

2. Vérifier les dépendances
   ```bash
   npm audit
   npm outdated
   ```

3. Vérifier les erreurs console
   ```javascript
   console.error('Erreur détaillée:', error);
   ```

## Monitoring

### 1. Problèmes Prometheus

#### Symptômes
- Métriques manquantes
- Erreurs de scrape
- Problèmes de stockage

#### Solutions
1. Vérifier les targets
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

2. Vérifier les règles
   ```bash
   curl http://localhost:9090/api/v1/rules
   ```

3. Vérifier le stockage
   ```bash
   du -sh /opt/monitoring/prometheus/data
   ```

### 2. Problèmes Grafana

#### Symptômes
- Dashboards non chargés
- Erreurs de datasource
- Problèmes d'authentification

#### Solutions
1. Vérifier les datasources
   ```bash
   curl -u admin:admin http://localhost:3000/api/datasources
   ```

2. Vérifier les logs
   ```bash
   docker logs grafana
   ```

3. Vérifier les permissions
   ```bash
   ls -l /opt/monitoring/grafana/
   ```

## Docker

### 1. Problèmes de Conteneurs

#### Symptômes
- Conteneurs non démarrés
- Erreurs de build
- Problèmes de réseau

#### Solutions
1. Vérifier les conteneurs
   ```bash
   docker ps -a
   docker logs <container_id>
   ```

2. Vérifier les images
   ```bash
   docker images
   docker history <image_id>
   ```

3. Vérifier le réseau
   ```bash
   docker network ls
   docker network inspect <network_id>
   ```

## CI/CD

### 1. Problèmes GitHub Actions

#### Symptômes
- Workflows échoués
- Erreurs de déploiement
- Problèmes de secrets

#### Solutions
1. Vérifier les logs
   - Consulter les logs GitHub Actions
   - Vérifier les permissions
   - Vérifier les secrets

2. Vérifier les dépendances
   ```bash
   npm audit
   mvn dependency:tree
   ```

3. Vérifier les configurations
   ```bash
   cat .github/workflows/*.yml
   ```

## Base de Données

### 1. Problèmes MySQL

#### Symptômes
- Erreurs de connexion
- Requêtes lentes
- Problèmes de réplication

#### Solutions
1. Vérifier les connexions
   ```sql
   SHOW PROCESSLIST;
   SHOW STATUS LIKE 'Threads_connected';
   ```

2. Vérifier les performances
   ```sql
   EXPLAIN SELECT * FROM your_table;
   SHOW INDEX FROM your_table;
   ```

3. Vérifier les logs
   ```bash
   tail -f /var/log/mysql/error.log
   ```

## Maintenance

### 1. Nettoyage

#### Tâches Régulières
1. Nettoyer les logs
   ```bash
   find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
   ```

2. Nettoyer Docker
   ```bash
   docker system prune -a
   ```

3. Nettoyer les backups
   ```bash
   find /backup -type f -mtime +30 -delete
   ```

### 2. Mises à Jour

#### Procédures
1. Mettre à jour les packages
   ```bash
   sudo yum update -y
   ```

2. Mettre à jour Docker
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

3. Mettre à jour les applications
   ```bash
   git pull
   mvn clean install
   npm install
   ```

## Ressources

### 1. Logs
- `/var/log/`
- `/opt/monitoring/logs/`
- `docker logs`

### 2. Documentation
- AWS Documentation
- Docker Documentation
- GitHub Actions Documentation

### 3. Support
- AWS Support
- GitHub Support
- Stack Overflow
