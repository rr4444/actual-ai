FROM node:22.21-alpine3.22

ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV

# Install build dependencies for native modules
RUN apk add --no-cache python3 make g++

# Create app directory and set ownership to node user
RUN mkdir -p /opt/node_app && chown -R node:node /opt/node_app

WORKDIR /opt/node_app

USER node

COPY --chown=node:node package.json package-lock.json* ./
RUN npm ci && npm cache clean --force
ENV PATH=/opt/node_app/node_modules/.bin:$PATH

WORKDIR /opt/node_app/app
COPY --chown=node:node . .

ARG VERSION=unknown
ARG COMMIT_HASH=unknown
ENV APP_VERSION=$VERSION
ENV APP_COMMIT_HASH=$COMMIT_HASH

# Overwrite version.ts with compile-time Git and package version info
USER root
RUN apk add --no-cache git && \
    VAL_VERSION="${VERSION}" && \
    if [ "$VAL_VERSION" = "unknown" ]; then VAL_VERSION=$(node -p "require('./package.json').version"); fi && \
    VAL_HASH="${COMMIT_HASH}" && \
    if [ "$VAL_HASH" = "unknown" ] && [ -d .git ]; then \
        git config --global --add safe.directory /opt/node_app/app && \
        VAL_HASH=$(git rev-parse --short HEAD); \
    fi && \
    echo "export const appVersion = '$VAL_VERSION';" > src/version.ts && \
    echo "export const commitHash = '$VAL_HASH';" >> src/version.ts && \
    chown node:node src/version.ts && \
    apk del git
USER node

RUN npm run build
CMD [ "node", "dist/app.js" ]

