FROM alpine:latest

# Installer curl (et les certificats pour HTTPS) puis créer un user non-root
RUN apk add --no-cache curl ca-certificates \
    && addgroup -S app && adduser -S -G app app

# Exécuter en tant qu'utilisateur non-root
USER app

# Lancer curl ; l'URL sera passée comme argument à `docker run`
ENTRYPOINT ["curl"]

docker build -t my-curl -f 3-curl.dockerfile .
