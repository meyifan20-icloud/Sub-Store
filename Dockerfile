# syntax=docker/dockerfile:1.7

FROM node:24-alpine AS backend-build
WORKDIR /src/backend

RUN corepack enable

COPY backend/package.json backend/pnpm-lock.yaml backend/pnpm-workspace.yaml ./
COPY backend/patches ./patches
RUN pnpm install --frozen-lockfile

COPY backend/ ./
COPY .node-version /src/.node-version
RUN pnpm bundle:esbuild

FROM alpine:3.22 AS runtime-assets

ARG TARGETARCH
ARG TARGETVARIANT
ARG FRONTEND_URL=https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip
ARG HTTP_META_URL=https://github.com/xream/http-meta/releases/latest/download/http-meta.bundle.js
ARG HTTP_META_TEMPLATE_URL=https://github.com/xream/http-meta/releases/latest/download/tpl.yaml
ARG MIHOMO_VERSION_URL=https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt
ARG MIHOMO_BASE_URL=https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha
ARG SHOUTRRR_BASE_URL=https://github.com/containrrr/shoutrrr/releases/latest/download

RUN apk add --no-cache ca-certificates curl tar unzip gzip

WORKDIR /opt/app

RUN set -eux; \
    curl -fL --retry 3 "$FRONTEND_URL" -o /tmp/frontend.zip; \
    mkdir -p /tmp/frontend; \
    unzip -q /tmp/frontend.zip -d /tmp/frontend; \
    if [ -d /tmp/frontend/dist ]; then mv /tmp/frontend/dist /opt/app/frontend; \
    else mkdir -p /opt/app/frontend && cp -a /tmp/frontend/. /opt/app/frontend/; fi; \
    rm -rf /tmp/frontend /tmp/frontend.zip

RUN set -eux; \
    mkdir -p /opt/app/http-meta; \
    curl -fL --retry 3 "$HTTP_META_URL" -o /opt/app/http-meta.bundle.js; \
    curl -fL --retry 3 "$HTTP_META_TEMPLATE_URL" -o /opt/app/http-meta/tpl.yaml

RUN set -eux; \
    case "$TARGETARCH/$TARGETVARIANT" in \
      amd64/) MIHOMO_ARCH="amd64-v1"; SHOUTRRR_ARCH="amd64" ;; \
      arm64/) MIHOMO_ARCH="arm64"; SHOUTRRR_ARCH="arm64" ;; \
      arm/v7) MIHOMO_ARCH="armv7"; SHOUTRRR_ARCH="armv6" ;; \
      *) echo "Unsupported architecture: $TARGETARCH/$TARGETVARIANT" >&2; exit 1 ;; \
    esac; \
    MIHOMO_VERSION="$(curl -fsSL "$MIHOMO_VERSION_URL" | tr -d '\r\n')"; \
    test -n "$MIHOMO_VERSION"; \
    curl -fL --retry 3 "$MIHOMO_BASE_URL/mihomo-linux-$MIHOMO_ARCH-$MIHOMO_VERSION.gz" \
      | gunzip > /opt/app/http-meta/http-meta; \
    chmod 755 /opt/app/http-meta/http-meta; \
    curl -fL --retry 3 "$SHOUTRRR_BASE_URL/shoutrrr_linux_$SHOUTRRR_ARCH.tar.gz" \
      | tar -xz -C /usr/local/bin shoutrrr; \
    chmod 755 /usr/local/bin/shoutrrr

FROM node:24-alpine AS runtime

ARG TIME_ZONE=Asia/Shanghai
ENV TZ=$TIME_ZONE \
    SUB_STORE_DOCKER=true \
    SUB_STORE_BACKEND_API_HOST=0.0.0.0 \
    SUB_STORE_BACKEND_API_PORT=3001 \
    SUB_STORE_BACKEND_MERGE=true \
    SUB_STORE_FRONTEND_BACKEND_PATH=/2cXaAxRGfddmGz2yx1wA \
    SUB_STORE_FRONTEND_PATH=/opt/app/frontend \
    SUB_STORE_DATA_BASE_PATH=/opt/app/data \
    HTTP_META_ENABLED=true \
    HTTP_META_HOST=127.0.0.1 \
    HTTP_META_PORT=9876

RUN apk add --no-cache ca-certificates tini tzdata && \
    cp "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime && \
    echo "$TIME_ZONE" > /etc/timezone

WORKDIR /opt/app

COPY --from=backend-build /src/backend/dist/sub-store.bundle.js /opt/app/sub-store.bundle.js
COPY --from=runtime-assets /opt/app/frontend /opt/app/frontend
COPY --from=runtime-assets /opt/app/http-meta.bundle.js /opt/app/http-meta.bundle.js
COPY --from=runtime-assets /opt/app/http-meta /opt/app/http-meta
COPY --from=runtime-assets /usr/local/bin/shoutrrr /usr/local/bin/shoutrrr
COPY deploy/runtime/start.sh /usr/local/bin/sub-store-start
COPY deploy/runtime/healthcheck.mjs /opt/app/healthcheck.mjs

RUN chmod 755 /usr/local/bin/sub-store-start && mkdir -p /opt/app/data

VOLUME ["/opt/app/data"]
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD ["node", "/opt/app/healthcheck.mjs"]

ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/sub-store-start"]
