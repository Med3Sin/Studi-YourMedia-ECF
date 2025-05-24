# Tests

## Vue d'ensemble

Ce document décrit les différents types de tests utilisés dans le projet YourMedia et comment les exécuter.

## Tests Backend (Java Spring Boot)

### Tests Unitaires

```bash
# Exécuter tous les tests unitaires
mvn test

# Exécuter une classe de test spécifique
mvn test -Dtest=UserServiceTest

# Exécuter un test spécifique
mvn test -Dtest=UserServiceTest#testCreateUser
```

### Tests d'Intégration

```bash
# Exécuter les tests d'intégration
mvn verify

# Exécuter les tests d'intégration avec un profil spécifique
mvn verify -P integration-test
```

### Tests de Performance

```bash
# Exécuter les tests de performance
mvn verify -P performance-test
```

## Tests Frontend (React)

### Tests Unitaires

```bash
# Exécuter tous les tests
npm test

# Exécuter les tests en mode watch
npm test -- --watch

# Exécuter les tests avec couverture
npm test -- --coverage
```

### Tests d'Intégration

```bash
# Exécuter les tests d'intégration
npm run test:integration
```

## Tests d'Infrastructure

### Tests Terraform

```bash
# Valider la configuration Terraform
terraform validate

# Planifier les changements
terraform plan
```

### Tests de Sécurité

```bash
# Scanner les vulnérabilités
npm audit
mvn dependency-check:check
```

## Tests de Monitoring

### Tests Prometheus

```bash
# Vérifier la configuration Prometheus
promtool check config prometheus.yml

# Vérifier les règles
promtool check rules rules.yml
```

### Tests Grafana

```bash
# Vérifier la configuration Grafana
grafana-cli admin check-config
```

## Tests de Performance

### Tests de Charge

```bash
# Exécuter les tests de charge avec JMeter
jmeter -n -t load-test.jmx -l results.jtl
```

### Tests de Stress

```bash
# Exécuter les tests de stress
./scripts/stress-test.sh
```

## Tests de Sécurité

### Tests de Pénétration

```bash
# Exécuter les tests de pénétration
./scripts/penetration-test.sh
```

### Tests de Configuration

```bash
# Vérifier la configuration de sécurité
./scripts/security-check.sh
```

## Tests de Déploiement

### Tests de CI/CD

```bash
# Vérifier les workflows GitHub Actions
act -j build

# Vérifier les scripts de déploiement
./scripts/verify-deployment.sh
```

## Bonnes Pratiques

1. Écrire des tests pour chaque nouvelle fonctionnalité
2. Maintenir une couverture de code élevée
3. Exécuter les tests avant chaque commit
4. Documenter les cas de test complexes
5. Utiliser des données de test réalistes
6. Nettoyer les ressources après les tests
7. Automatiser l'exécution des tests
8. Maintenir les tests à jour

## Dépannage

### Problèmes Courants

1. Tests qui échouent de manière intermittente
2. Problèmes de configuration
3. Données de test obsolètes
4. Problèmes de performance

### Solutions

1. Vérifier les logs de test
2. Mettre à jour les données de test
3. Vérifier la configuration
4. Optimiser les tests lents 