# YourMedia - Plateforme de Streaming Vidéo

## Vue d'ensemble

YourMedia est une plateforme de streaming vidéo moderne construite avec Java/Spring Boot pour le backend et React Native/Expo pour le frontend. Le projet utilise une infrastructure AWS gérée par Terraform et un système de monitoring complet basé sur Prometheus, Grafana et Loki.

## Structure du projet

```
.
├── app-java/                 # Application backend Java/Spring Boot
├── app-react/               # Application frontend React Native/Expo
├── docs/                    # Documentation complète du projet
├── infrastructure/          # Configuration Terraform
└── scripts/                 # Scripts d'automatisation
```

## Documentation

La documentation complète est organisée dans le dossier `docs/` :

- [Architecture](docs/ARCHITECTURE.md) - Architecture globale du système
- [Applications](docs/APPLICATIONS.md) - Détails des applications backend et frontend
- [Infrastructure](docs/INFRASTRUCTURE.md) - Configuration AWS et Terraform
- [Monitoring](docs/MONITORING.md) - Configuration du monitoring
- [Sécurité](docs/SECURITE.md) - Mesures de sécurité
- [Workflows](docs/WORKFLOWS.md) - CI/CD et automatisation

## Prérequis

- Java 17
- Node.js 16
- Terraform 1.5.0
- AWS CLI
- Docker

## Installation

1. Cloner le repository :
```bash
git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git
cd Studi-YourMedia-ECF
```

2. Configurer les variables d'environnement :
```bash
cp .env.example .env
# Éditer .env avec vos configurations
```

3. Déployer l'infrastructure :
```bash
cd infrastructure
terraform init
terraform apply
```

4. Déployer les applications :
```bash
# Backend
cd app-java
mvn clean package
./deploy-war.sh

# Frontend
cd app-react
npm install
npm run build
```

## Développement

### Backend (Java)
```bash
cd app-java
mvn spring-boot:run
```

### Frontend (React Native)
```bash
cd app-react
npm start
```

## Monitoring

Le système de monitoring est accessible via :
- Grafana : http://[monitoring-ip]:3000
- Prometheus : http://[monitoring-ip]:9090
- Loki : http://[monitoring-ip]:3100

## Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add some AmazingFeature'`)
4. Push sur la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Contact

MedSin - [@Med3Sin](https://github.com/Med3Sin)

Lien du projet : [https://github.com/Med3Sin/Studi-YourMedia-ECF](https://github.com/Med3Sin/Studi-YourMedia-ECF)