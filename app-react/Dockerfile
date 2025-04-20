FROM node:16-alpine AS builder

# Installer les dépendances nécessaires pour React Native
RUN apk add --no-cache bash git openssh

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY package.json package-lock.json ./

# Installer les dépendances
RUN npm install

# Copier le reste du code source
COPY . .

# Installer Expo CLI globalement
RUN npm install -g expo-cli

# Construire l'application pour le web (version mobile-responsive)
RUN npm run build

# Étape finale pour réduire la taille de l'image
FROM node:16-alpine

# Installer un serveur web léger
RUN npm install -g serve

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de build depuis l'étape précédente
COPY --from=builder /app/build /app/build

# Exposer le port
EXPOSE 3000

# Variables d'environnement (seront remplacées lors du déploiement)
ENV API_URL=http://localhost:8080
ENV NODE_ENV=production

# Commande de démarrage
CMD ["serve", "-s", "build", "-l", "3000"]
