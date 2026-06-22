# ─── Stage 1: builder ─────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# git is needed for build-time version stamping via `git describe`.
RUN apk add --no-cache git

WORKDIR /build

# Download dependencies as a separate layer so they are cached across
# source-only changes.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Resolve build metadata from git at image-build time.
ARG VERSION
ARG COMMIT
ARG BUILD_DATE

RUN VERSION=${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo "dev")} && \
    COMMIT=${COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")} && \
    BUILD_DATE=${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")} && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -ldflags="-w -s \
        -X main.version=${VERSION} \
        -X main.commit=${COMMIT} \
        -X main.buildDate=${BUILD_DATE}" \
      -o /app/api \
      ./cmd/api

# ─── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM alpine:3.21

# ca-certificates: required for HTTPS calls to external services (TURN, APNs, etc.)
# tzdata: correct timezone handling in PostgreSQL TIMESTAMPTZ comparisons
RUN apk add --no-cache ca-certificates tzdata wget && \
    addgroup -g 1001 syncbridge && \
    adduser  -u 1001 -G syncbridge -D -s /sbin/nologin syncbridge

WORKDIR /app

COPY --from=builder /app/api        ./api
COPY --from=builder /build/migrations ./migrations

RUN chown -R syncbridge:syncbridge /app

USER syncbridge:syncbridge

EXPOSE 8080

# Kubernetes liveness probe — uses the lightweight /health endpoint.
HEALTHCHECK \
    --interval=30s \
    --timeout=5s  \
    --start-period=15s \
    --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

ENTRYPOINT ["./api"]
