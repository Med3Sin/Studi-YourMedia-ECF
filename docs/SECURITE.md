# Sécurité - YourMédia

Ce document détaille les mesures de sécurité mises en place pour le projet YourMédia, couvrant l'infrastructure, les applications et les données.

## Table des matières

1. [Infrastructure](#infrastructure)
2. [Applications](#applications)
3. [Données](#données)
4. [Accès](#accès)
5. [Monitoring](#monitoring)
6. [Audit](#audit)

## Infrastructure

### EC2

#### Configuration de base

- Mises à jour automatiques activées
- Accès SSH restreint aux IPs autorisées
- Rôles IAM avec privilèges minimaux
- Security Groups configurés avec le principe du moindre privilège

#### Instance Java/Tomcat

- Type : t2.micro
- AMI : Amazon Linux 2023
- Stockage : 8 Go gp2
- AZ : eu-west-3a
- Accès SSH : Via GitHub Secrets
- Services :
  - Tomcat 9 avec configuration sécurisée
  - Java 11 avec paramètres de sécurité
  - JMX Exporter avec authentification

#### Instance Monitoring

- Type : t2.micro
- AMI : Amazon Linux 2023
- Stockage : 8 Go gp2
- AZ : eu-west-3a
- Accès SSH : Via GitHub Secrets
- Services :
  - Prometheus avec authentification
  - Grafana avec OAuth2
  - Loki avec chiffrement
  - Promtail avec filtrage des logs sensibles

### Docker

#### Configuration des conteneurs

- Utilisation d'utilisateurs non-root
- Capabilities Linux limitées
- Réseaux isolés
- Volumes en lecture seule quand possible
- Ressources limitées (CPU, mémoire)

#### Exemple de configuration

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    user: "65534:65534"  # nobody:nogroup
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp
    volumes:
      - prometheus_data:/prometheus:ro
    networks:
      - monitoring
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Services Systemd

#### docker-cleanup.service

```ini
[Unit]
Description=Docker Cleanup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=ec2-user
Group=docker
ExecStart=/usr/local/bin/docker-cleanup.sh
Environment=DOCKER_CLEANUP_DRY_RUN=false
Environment=DOCKER_CLEANUP_OLDER_THAN=24h
Environment=DOCKER_CLEANUP_MAX_IMAGES=10
Environment=DOCKER_CLEANUP_MAX_CONTAINERS=5

[Timer]
OnCalendar=daily
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

#### sync-tomcat-logs.service

```ini
[Unit]
Description=Tomcat Logs Synchronization Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=ec2-user
Group=docker
ExecStart=/usr/local/bin/sync-tomcat-logs.sh
Environment=TOMCAT_LOG_DIR=/var/log/tomcat
Environment=LOKI_ENDPOINT=http://localhost:3100
Environment=LOKI_RETENTION_PERIOD=7d
Environment=LOG_SYNC_INTERVAL=1h

[Timer]
OnCalendar=hourly
AccuracySec=1m
Persistent=true

[Install]
WantedBy=timers.target
```

## Applications

### Backend Java

- Spring Security avec JWT
- Validation des entrées
- Protection CSRF
- Headers de sécurité
- Logging sécurisé

### Frontend React

- HTTPS obligatoire
- CSP configuré
- XSS protection
- CORS configuré
- Sanitization des entrées

## Données

### Chiffrement

- Au repos :
  - S3 : SSE-S3
  - RDS : Chiffrement des données
  - EBS : Chiffrement des volumes
- En transit :
  - TLS 1.2+
  - Certificats valides
  - Perfect Forward Secrecy

### Sauvegarde

- RDS : Backups quotidiens
- S3 : Versioning activé
- Logs : Rétention 7 jours
- Rotation des clés

## Accès

### Authentification

- SSH : Clés uniquement
- JWT : Tokens courts
- Base de données : Utilisateurs dédiés
- S3 : IAM roles

### Autorisation

- IAM : Privilèges minimaux
- RDS : Utilisateurs dédiés
- S3 : Bucket policies
- API : RBAC

## Monitoring

### Prometheus

- Authentification basique
- TLS pour les endpoints
- Filtrage des métriques sensibles
- Rétention limitée

### Grafana

- OAuth2 avec GitHub
- Rôles et permissions
- Audit logging
- Session timeout

### Loki

- Chiffrement des logs
- Filtrage des données sensibles
- Rétention configurée
- Accès restreint

## Audit

### Logs

- Accès SSH
- Modifications système
- Accès API
- Erreurs sécurité

### Alertes

- Tentatives de connexion échouées
- Modifications de configuration
- Accès non autorisés
- Anomalies système

## Améliorations futures

1. **Sécurité avancée**
   - WAF
   - Shield
   - GuardDuty
   - Security Hub

2. **Conformité**
   - ISO 27001
   - SOC 2
   - GDPR
   - PCI DSS

3. **Monitoring**
   - Détection d'intrusion
   - Analyse comportementale
   - Threat intelligence
   - Forensics

4. **Accès**
   - MFA
   - SSO
   - PAM
   - Zero Trust

## Ressources

- [Documentation AWS Security](https://docs.aws.amazon.com/security)
- [Documentation Docker Security](https://docs.docker.com/engine/security)
- [Documentation Spring Security](https://docs.spring.io/spring-security)
- [Documentation OWASP](https://owasp.org)
