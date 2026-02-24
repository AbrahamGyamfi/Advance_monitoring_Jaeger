# Backend Dockerfile
FROM node:18-alpine

ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_NUMBER

LABEL maintainer="Abraham Gyamfi <abraham.gyamfi@dev.com>"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${BUILD_NUMBER}"
LABEL org.opencontainers.image.title="TaskFlow Backend"
LABEL org.opencontainers.image.description="Node.js backend for TaskFlow application"

WORKDIR /app

RUN apk add --no-cache wget

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node app.js logger.js metrics.js server.js telemetry.js ./
USER node

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -q --spider http://localhost:5000/health || exit 1

CMD ["node", "server.js"]
