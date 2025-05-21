# YourMedia - Plateforme de Streaming

## Vue d'ensemble

YourMedia est une plateforme de streaming moderne construite avec Spring Boot et React Native. Ce projet implémente une architecture cloud-native sur AWS avec un système de monitoring complet.

## Documentation

La documentation du projet est organisée dans le dossier `docs/` :

- [Documentation Générale](docs/README.md) - Vue d'ensemble du projet
- [Architecture](docs/ARCHITECTURE.md) - Détails de l'architecture système
- [Déploiement](docs/DEPLOYMENT.md) - Guide de déploiement
- [Monitoring](docs/MONITORING.md) - Configuration et utilisation du monitoring
- [Scripts](docs/SCRIPTS.md) - Documentation des scripts utilitaires
- [API](docs/API.md) - Documentation de l'API REST
- [Base de Données](docs/DATABASE.md) - Schéma et migrations de la base de données

## Structure du Projet

```
.
├── app-java/           # Application Spring Boot
├── app-react/         # Application React Native
├── docs/              # Documentation
├── infrastructure/    # Terraform pour AWS
├── scripts/           # Scripts de déploiement et utilitaires
└── .github/          # GitHub Actions workflows
```

## Prérequis

- Java 17
- Node.js 18+
- Docker et Docker Compose
- AWS CLI
- Terraform 1.0+

## Installation Rapide

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

3. Démarrer l'infrastructure :
   ```bash
   cd infrastructure
   terraform init
   terraform apply
   ```

4. Déployer l'application :
   ```bash
   ./scripts/deploy.sh
   ```

## Monitoring

Le système de monitoring comprend :
- Prometheus pour la collecte de métriques
- Grafana pour la visualisation
- cAdvisor pour les métriques Docker
- Loki pour la gestion des logs
- Promtail pour la collecte des logs

Voir [Documentation Monitoring](docs/MONITORING.md) pour plus de détails.

## Développement

### Backend (Java)

```bash
cd app-java
./mvnw spring-boot:run
```

### Frontend (React Native)

```bash
cd app-react
npm install
npm start
```

## Tests

```bash
# Tests backend
cd app-java
./mvnw test

# Tests frontend
cd app-react
npm test
```

## CI/CD

Le projet utilise GitHub Actions pour l'intégration et le déploiement continu. Les workflows sont définis dans `.github/workflows/`.

## Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'feat: Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Contact

Med3Sin - [@Med3Sin](https://github.com/Med3Sin)

Lien du projet : [https://github.com/Med3Sin/Studi-YourMedia-ECF](https://github.com/Med3Sin/Studi-YourMedia-ECF)