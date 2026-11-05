# "Bundle" image of the Script Application: it only carries the BUILT app (dist/) in /app.
# The chart's Job copies it out of this image and pushes it to DX with DXClient.
# Built by CI; its tag is the app version (package.json).

# 1. Build the app
FROM node:24.22.1-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run lint && npm run build

# 2. Small runtime with "cp" (busybox), the files and nothing else
FROM busybox:1.37.0
COPY --from=build --chown=1000:1000 /src/dist /app
USER 1000:1000
CMD ["ls", "-lR", "/app"]
