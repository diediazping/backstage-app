# Build stage
FROM node:18-bullseye-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    g++ \
    make \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files first for better layer caching
COPY package.json yarn.lock ./
COPY packages/backend/package.json ./packages/backend/
COPY packages/*/package.json ./packages/*/
COPY plugins/*/package.json ./plugins/*/

# Install dependencies
RUN yarn install --frozen-lockfile --network-timeout 600000

# Copy source code
COPY . .

# Build the backend
RUN yarn build:backend --config app-config.production.yaml

# Production stage
FROM node:18-bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -r backstage && useradd -r -g backstage -m backstage

WORKDIR /app

# Copy built application with correct ownership
COPY --from=builder --chown=backstage:backstage /app/packages/backend/dist/bundle.tar.gz ./

# Extract and clean up
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

# Copy app-config for production
COPY --from=builder --chown=backstage:backstage /app/app-config.production.yaml ./

# Install only production dependencies for the runtime
COPY --from=builder --chown=backstage:backstage /app/yarn.lock /app/package.json ./
RUN yarn install --frozen-lockfile --production && yarn cache clean

# Switch to non-root user
USER backstage

# Expose port
EXPOSE 7007

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:7007/api/catalog/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "packages/backend"]
