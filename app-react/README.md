# YourMedia Frontend

Application frontend React Native/Expo pour la plateforme YourMedia.

## Prérequis

- Node.js 16
- npm 8+
- Expo CLI
- Android Studio (pour le développement Android)
- Xcode (pour le développement iOS, macOS uniquement)

## Structure du projet

```
app-react/
├── src/
│   ├── components/          # Composants réutilisables
│   ├── screens/            # Écrans de l'application
│   ├── services/           # Services API
│   ├── utils/              # Utilitaires
│   └── App.js             # Point d'entrée
├── assets/                 # Images, fonts, etc.
├── app.json               # Configuration Expo
└── package.json           # Dépendances
```

## Configuration

### app.json
```json
{
  "expo": {
    "name": "YourMedia",
    "slug": "yourmedia",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "updates": {
      "fallbackToCacheTimeout": 0
    },
    "assetBundlePatterns": [
      "**/*"
    ],
    "ios": {
      "supportsTablet": true
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#FFFFFF"
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    }
  }
}
```

### Dépendances principales

```json
{
  "dependencies": {
    "@expo/metro-runtime": "~3.1.1",
    "expo": "~50.0.5",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "react-native": "0.73.2",
    "react-native-web": "~0.19.6"
  }
}
```

## Développement

1. Cloner le repository :
```bash
git clone https://github.com/Med3Sin/Studi-YourMedia-ECF.git
cd Studi-YourMedia-ECF/app-react
```

2. Installer les dépendances :
```bash
npm install
```

3. Lancer l'application :
```bash
# Développement web
npm run web

# Développement Android
npm run android

# Développement iOS
npm run ios
```

## Build et déploiement

1. Build pour le web :
```bash
npm run build
```

2. Build pour Android :
```bash
expo build:android
```

3. Build pour iOS :
```bash
expo build:ios
```

## Fonctionnalités

- Streaming vidéo
- Gestion des playlists
- Recherche de contenu
- Profil utilisateur
- Mode hors ligne

## Tests

```bash
# Exécuter les tests
npm test

# Exécuter les tests avec couverture
npm test -- --coverage
```

## Documentation

Pour plus de détails, consultez :
- [Documentation Expo](https://docs.expo.dev)
- [Documentation React Native](https://reactnative.dev/docs/getting-started)
- [Documentation React](https://reactjs.org/docs/getting-started.html)
