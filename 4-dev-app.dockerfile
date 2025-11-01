# Image légère + npm moderne
FROM node:20-alpine

# Dossier de travail
WORKDIR /app

# 1) Installer les dépendances (en production)
# - On copie d'abord uniquement les manifests pour profiter du cache
COPY package*.json ./

# - npm ci si un package-lock.json existe ; sinon npm install
# - --omit=dev = n'installe pas les devDependencies (suffisant pour exécuter l'app)
RUN npm ci --omit=dev || npm install --omit=dev

# 2) Copier le code de l'app
COPY . .

# 3) Créer un utilisateur non-root et corriger les permissions
RUN addgroup -S app && adduser -S -G app app && chown -R app:app /app
USER app

# 4) L'app écoute sur 3000 (documentation)
EXPOSE 3000

# 5) Point d'entrée (notes disent "entry point is server.js")
CMD ["node", "server.js"] 
