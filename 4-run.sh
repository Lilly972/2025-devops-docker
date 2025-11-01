#!/usr/bin/env bash
set -euo pipefail

# Build: contexte = broken-app/
docker build -t dev-app -f 4-dev-app.dockerfile broken-app

echo "=== Lancement sur http://localhost:3000 ==="
# -p 3000:3000 pour exposer sur ta machine
docker run --rm --name dev-app -p 3000:3000 dev-app
