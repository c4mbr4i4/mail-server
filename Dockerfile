FROM alpine:3.20

LABEL org.opencontainers.image.title="mailu-coolify-helper"
LABEL org.opencontainers.image.description="Helper image for documentation-only Coolify Dockerfile builds. Use docker-compose.yml for the mail stack."

WORKDIR /app
COPY README.md /app/README.md

CMD ["sh", "-c", "printf '%s\n' 'Este projeto deve ser implantado no Coolify como Docker Compose/Raw Compose. Consulte README.md.' && sleep infinity"]
