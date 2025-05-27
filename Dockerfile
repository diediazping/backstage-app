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

# Copiar configuración personalizada si existe
COPY app-config.production.yaml ./packages/backend/app-config.production.yaml

# Construir la aplicación
RUN yarn build:backend --config app-config.production.yaml

# Production stage
FROM node:18-bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app && \
    groupadd -r backstage && \
    useradd -r -g backstage -d /app backstage && \
    chown backstage:backstage /app


WORKDIR /app
USER backstage

# CORRECCIÓN PRINCIPAL: Copiar los node_modules también
COPY --from=builder --chown=backstage:backstage /app/backstage-app/packages/backend/dist ./packages/backend/dist
COPY --from=builder --chown=backstage:backstage /app/backstage-app/node_modules ./node_modules
COPY --from=builder --chown=backstage:backstage /app/backstage-app/packages/backend/node_modules ./packages/backend/node_modules
COPY --from=builder --chown=backstage:backstage /app/backstage-app/app-config*.yaml ./
COPY --from=builder --chown=backstage:backstage /app/backstage-app/package.json ./

EXPOSE 7007

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:7007/api/catalog/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "packages/backend"]
