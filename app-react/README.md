# YourMedia Frontend

Ce répertoire contient le code source de l'application frontend pour le projet YourMedia.

## Structure du projet

L'application est développée avec React Native Web, permettant une expérience utilisateur fluide et réactive.

```
app-react/
├── assets/             # Images, polices et autres ressources statiques
├── dist/               # Fichiers de build générés
├── node_modules/       # Dépendances (générées par npm/yarn)
├── App.js              # Composant principal de l'application
├── app.json            # Configuration de l'application
├── package.json        # Configuration des dépendances et scripts
└── package-lock.json   # Verrouillage des versions des dépendances
```

## Prérequis

- Node.js 14 ou supérieur
- npm 6 ou supérieur (ou yarn)

## Installation des dépendances

Pour installer les dépendances, exécutez la commande suivante :

```bash
npm install
# ou
yarn
```

## Développement

Pour démarrer le serveur de développement, exécutez :

```bash
npm start
# ou
yarn start
```

Cela lancera l'application en mode développement. Ouvrez [http://localhost:3000](http://localhost:3000) pour la voir dans votre navigateur.

## Build

Pour créer une version de production, exécutez :

```bash
npm run build
# ou
yarn build
```

Cela générera les fichiers statiques dans le répertoire `dist/`.

## Déploiement

Le déploiement est géré automatiquement par AWS Amplify, qui est configuré pour surveiller les changements sur la branche `main` du dépôt GitHub.

## Configuration

L'application peut être configurée via les variables d'environnement suivantes :

- `REACT_APP_API_URL` : URL de l'API backend
- `REACT_APP_S3_BUCKET` : Nom du bucket S3 pour le stockage des médias

Ces variables peuvent être définies dans un fichier `.env` à la racine du projet.
