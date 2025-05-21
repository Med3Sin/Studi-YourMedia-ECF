# Architecture

## Vue d'ensemble

Ce document décrit l'architecture du projet YourMedia, détaillant les composants, leurs interactions et les choix techniques.

## Infrastructure AWS

### 1. Réseau

#### VPC
- VPC principal: 10.0.0.0/16
- Sous-réseaux publics: 10.0.1.0/24, 10.0.2.0/24
- Sous-réseaux privés: 10.0.3.0/24, 10.0.4.0/24
- NAT Gateway pour l'accès Internet
- Internet Gateway pour les services publics

#### Sécurité
- Security Groups par service
- NACLs par sous-réseau
- WAF pour l'API Gateway
- Shield pour la protection DDoS

### 2. Compute

#### EC2
- Instance type: t3.micro (dev), t3.small (prod)
- AMI: Amazon Linux 2023
- EBS: gp3, 20GB
- User Data pour l'initialisation

#### Auto Scaling
- Min: 1 instance
- Max: 3 instances
- Target: 70% CPU
- Health checks: ELB

### 3. Base de données

#### RDS MySQL
- Instance type: db.t3.micro
- Storage: 20GB gp2
- Multi-AZ: Non (dev), Oui (prod)
- Backup: 7 jours

#### Configuration
- Charset: utf8mb4
- Collation: utf8mb4_unicode_ci
- Parameters group personnalisé
- Option group: MySQL 8.0

## Applications

### 1. Backend (Java)

#### Spring Boot
- Version: 2.7.x
- Java: 11
- Maven pour le build
- JPA/Hibernate

#### Architecture
- Controllers REST
- Services métier
- Repositories
- DTOs

#### Sécurité
- Spring Security
- JWT
- CORS
- Rate limiting

### 2. Frontend (React)

#### React
- Version: 18.x
- TypeScript
- npm pour le build
- Redux pour l'état

#### Architecture
- Components
- Hooks
- Context
- Services

#### UI/UX
- Material-UI
- Responsive design
- PWA
- i18n

## Monitoring

### 1. Prometheus

#### Configuration
- Scrape interval: 15s
- Retention: 15 jours
- Alert rules
- Recording rules

#### Métriques
- Node Exporter
- cAdvisor
- Spring Boot Actuator
- Custom metrics

### 2. Grafana

#### Dashboards
- System Overview
- Java Application
- React Application
- Logs

#### Alerting
- Email notifications
- Slack integration
- PagerDuty
- Escalation

### 3. Loki

#### Configuration
- Retention: 30 jours
- Chunks
- Index
- Storage

#### Logs
- Application logs
- System logs
- Access logs
- Error logs

## CI/CD

### 1. GitHub Actions

#### Workflows
- Build & Test
- Security Scan
- Deploy Dev
- Deploy Prod

#### Environnements
- Development
- Staging
- Production

### 2. Docker

#### Images
- Java: openjdk:11-jre
- React: node:18-alpine
- Monitoring: prom/prometheus, grafana/grafana

#### Compose
- Services
- Networks
- Volumes
- Environment

## Sécurité

### 1. IAM

#### Rôles
- EC2: ssm, s3
- RDS: rds
- Lambda: cloudwatch

#### Politiques
- Least privilege
- Resource-based
- Tag-based
- Time-based

### 2. Chiffrement

#### Données
- Au repos: KMS
- En transit: TLS 1.2+
- Backups: SSE
- Keys: Rotation

## Maintenance

### 1. Backup

#### RDS
- Daily snapshots
- Point-in-time recovery
- Cross-region
- Retention

#### EBS
- Daily snapshots
- Lifecycle policy
- Cross-region
- Retention

### 2. Mises à jour

#### Système
- Security patches
- Minor updates
- Major updates
- Testing

#### Applications
- Dependencies
- Frameworks
- Libraries
- Testing

## Documentation

### 1. Technique

#### Architecture
- Diagrams
- Components
- Interactions
- Decisions

#### API
- Endpoints
- Models
- Authentication
- Examples

### 2. Opérationnelle

#### Procédures
- Deployment
- Monitoring
- Maintenance
- Troubleshooting

#### Runbooks
- Incidents
- Recovery
- Scaling
- Security
