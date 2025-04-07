# Application Frontend - React Native Web (app-react)

Ce répertoire contient le code source de l'application frontend de YourMédia, développée avec React Native et Expo, configurée pour un déploiement web.

## Fonctionnalités (Placeholder)

*   **Affichage "Hello World"**: Affiche un simple message de bienvenue.
*   **Build Web**: Configurée avec Expo pour générer un build web statique (HTML, CSS, JS) via la commande `npm run build` (ou `yarn build`).

## Prérequis pour le Développement Local

*   Node.js (version 18 ou supérieure recommandée)
*   npm ou yarn
*   Expo CLI (`npm install -g expo-cli` ou `yarn global add expo-cli`)

## Développement Local

Pour lancer l'application en mode développement (web) :

```bash
# Depuis la racine du projet global
cd app-react
npm install # ou yarn install
npm run web # ou yarn web
```

Ceci ouvrira l'application dans votre navigateur web.

## Build pour le Déploiement Web

Pour générer les fichiers statiques pour le déploiement :

```bash
# Depuis la racine du projet global
cd app-react
npm install # ou yarn install
npm run build # ou yarn build
```

Les fichiers statiques seront générés dans le répertoire `app-react/web-build/`.

## Déploiement

Le déploiement est géré par **AWS Amplify Hosting**.

1.  **Infrastructure**: La ressource `aws_amplify_app` est créée via Terraform (`infrastructure/main.tf`). Elle est configurée pour se connecter à ce repository GitHub.
2.  **Build & Déploiement Automatique**: Amplify est configuré pour écouter les `push` sur la branche `main`. À chaque push, Amplify :
    *   Récupère le code.
    *   Exécute les commandes de build définies dans `build_spec` (essentiellement `npm install` et `npm run build`).
    *   Déploie les artefacts générés (contenu du dossier `web-build/`) sur son infrastructure d'hébergement global (CDN).
3.  **CI Check**: Le workflow GitHub Actions `4-frontend-deploy.yml` sert de vérification d'intégration continue. Il s'assure que les dépendances s'installent et que le build (`npm run build`) réussit à chaque push sur `main`, mais il ne déploie *pas* directement sur Amplify (Amplify le fait lui-même).

L'application sera accessible via l'URL fournie par Amplify (visible dans la console AWS Amplify après le déploiement).
