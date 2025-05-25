FROM node:18-bullseye-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./
COPY packages packages
COPY plugins plugins

# Install dependencies
RUN yarn install --frozen-lockfile --network-timeout 600000

# Copy source code
COPY . .

# Build the app
RUN yarn build:backend --config app-config.production.yaml

# Production stage
FROM node:18-bullseye-slim

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r backstage && useradd -r -g backstage backstage

WORKDIR /app

# Copy built application
COPY --from=builder --chown=backstage:backstage /app/packages/backend/dist/bundle.tar.gz .
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Switch to non-root user
USER backstage

EXPOSE 7007

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:7007/healthcheck || exit 1

CMD ["node", "packages/backend"]
