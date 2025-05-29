# Este Dockerfile INSTALA Backstage desde cero
FROM node:18-bullseye-slim as builder

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    python3 \
    g++ \
    make \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar Backstage CLI globalmente
RUN npm install -g @backstage/create-app

# Crear una nueva aplicación Backstage
# (Esto es interactivo, así que necesitamos automatizarlo)
RUN echo "backstage-app" | npx @backstage/create-app@latest --skip-install

# Cambiar al directorio de la aplicación
WORKDIR /app/backstage-app

# Instalar dependencias
RUN yarn add @testing-library/react@^16.0.0 react@^18.0.0 react-dom@^18.0.0

RUN yarn install --immutable --network-timeout 600000



# Copiar configuración personalizada y renombrarla como app-config.yaml
COPY app-config.production.yaml ./app-config.yaml
COPY app-config.production.yaml ./packages/backend/app-config.yaml

RUN yarn --cwd ./packages/backend add pg
# Construir la aplicación
RUN yarn build:all


# Production stage
FROM node:18-bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    git \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app && \
    groupadd -r backstage && \
    useradd -r -g backstage -d /app backstage && \
    chown backstage:backstage /app

WORKDIR /app
USER backstage


# Copiar TODA la aplicación construida (approach más seguro)
COPY --from=builder --chown=backstage:backstage /app/backstage-app ./

# DEBUG en runtime: Ver qué tenemos disponible
RUN echo "=== RUNTIME FILES ===" && \
    ls -la . && \
    ls -la packages/backend/ && \
    ls -la packages/backend/dist/ 2>/dev/null || echo "No dist directory found" && \
    echo "=== END RUNTIME FILES ==="

EXPOSE 7007 


ENTRYPOINT ["dumb-init", "--"]
#CMD ["sh", "-c", "yarn start  2>/dev/null"]
#CMD ["sh", "-c", "node packages/backend/dist/index.js --config app-config.yaml & yarn workspace @backstage/app-default start"]
CMD ["sh", "-c", "if yarn workspace backend start 2>/dev/null; then exit 0; elif yarn dev 2>/dev/null; then exit 0; elif node packages/backend/dist/index.js 2>/dev/null; then exit 0; else echo 'No suitable start command found' && yarn --help; fi"]
