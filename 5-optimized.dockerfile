# ---------- Stage 1: build ----------
FROM golang:1.22-alpine AS builder
WORKDIR /src

# 1) Cache des modules
COPY go.mod go.sum ./
RUN go mod download

# 2) Copier le reste du code de l'app (le contexte de build = go-app/)
COPY . .

# 3) Build d'un binaire statique, léger et reproductible
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/app .

# ---------- Stage 2: runtime minimal et non-root ----------
# distroless static = ultra-minimal, sans shell, utilisateur nonroot par défaut
FROM gcr.io/distroless/static:nonroot
WORKDIR /app
COPY --from=builder /out/app /app/app

# L'API écoute sur 8080
EXPOSE 8080

# Sécurité : exécuter en non-root (déjà le cas avec cette image)
USER nonroot

ENTRYPOINT ["/app/app"]
