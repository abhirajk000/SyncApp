# SyncBridge API — Makefile
# Run `make help` to see all available targets.
# ──────────────────────────────────────────────────────────────────────────────

APP        := syncbridge-api
BIN_DIR    := bin
BIN        := $(BIN_DIR)/api
MAIN       := ./cmd/api
MIGRATIONS := ./migrations

DOCKER_COMP := docker compose

# Build metadata injected via -ldflags at compile time.
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS    := -ldflags="-w -s \
	-X main.version=$(VERSION) \
	-X main.commit=$(COMMIT) \
	-X main.buildDate=$(BUILD_DATE)"

.DEFAULT_GOAL := help

.PHONY: all build run test test-cover test-race bench vet fmt tidy \
        migrate-up migrate-down migrate-status \
        docker-build docker-up docker-down docker-logs docker-clean \
        clean help

# ── Build ─────────────────────────────────────────────────────────────────────

all: tidy build ## Tidy dependencies, then build

build: ## Compile binary to bin/api
	@mkdir -p $(BIN_DIR)
	go build $(LDFLAGS) -o $(BIN) $(MAIN)
	@echo "→ $(BIN) ($(VERSION))"

run: ## Run with go run (hot-reload friendly)
	go run $(LDFLAGS) $(MAIN)

# ── Quality ───────────────────────────────────────────────────────────────────

test: ## Run all tests with the race detector
	go test ./... -race -count=1 -timeout 60s

test-cover: ## Run tests and open an HTML coverage report (target: ≥80%)
	go test ./... -race -count=1 -timeout 120s \
	    -coverprofile=coverage.out -covermode=atomic
	go tool cover -func=coverage.out | tail -1
	go tool cover -html=coverage.out -o coverage.html
	@echo "→ coverage.html written; open it in your browser"

bench: ## Run all benchmarks (3 s each)
	go test ./... -run='^$$' -bench=. -benchtime=3s -benchmem | tee bench.txt
	@echo "→ bench.txt written"

vet: ## Run go vet
	go vet ./...

fmt: ## Format all Go source files
	gofmt -w -s .

tidy: ## Tidy and verify go.mod / go.sum
	go mod tidy
	go mod verify

# ── Migrations ────────────────────────────────────────────────────────────────
# Migrations run automatically on startup when RUN_MIGRATIONS=true (default).
# These targets let you run them manually — useful for CI and ops work.

migrate-up: ## Apply all pending migrations
	@$(call require_env,DATABASE_URL)
	go run $(LDFLAGS) $(MAIN) migrate up

migrate-down: ## Roll back the most recent migration
	@$(call require_env,DATABASE_URL)
	go run $(LDFLAGS) $(MAIN) migrate down 1

migrate-status: ## Print migration state for all versions
	@$(call require_env,DATABASE_URL)
	go run $(LDFLAGS) $(MAIN) migrate status

# ── Docker ────────────────────────────────────────────────────────────────────

docker-build: ## Build the Docker image (tag: syncbridge-api:latest)
	docker build \
	  --build-arg VERSION=$(VERSION) \
	  --build-arg COMMIT=$(COMMIT)   \
	  --build-arg BUILD_DATE=$(BUILD_DATE) \
	  -t $(APP):latest .

docker-up: ## Build and start all Compose services in the background
	$(DOCKER_COMP) up --build -d
	@echo "→ API:        http://localhost:8080"
	@echo "→ Health:     http://localhost:8080/health"
	@echo "→ Ready:      http://localhost:8080/ready"
	@echo "→ Version:    http://localhost:8080/version"
	@echo "→ Diagnostics http://localhost:8080/api/v1/diagnostics  (requires auth)"
	@echo "→ MinIO UI:   http://localhost:9001  (minioadmin / minioadmin)"
	@echo "→ Postgres:   localhost:5432          (syncbridge / syncbridge)"

docker-down: ## Stop and remove Compose containers
	$(DOCKER_COMP) down

docker-logs: ## Stream API container logs (Ctrl-C to stop)
	$(DOCKER_COMP) logs -f api

docker-clean: ## Remove containers, volumes, and locally-built images
	$(DOCKER_COMP) down -v --rmi local

# ── Housekeeping ──────────────────────────────────────────────────────────────

clean: ## Remove compiled binaries
	rm -rf $(BIN_DIR)

help: ## Show this help message
	@printf "\nUsage: make \033[36m<target>\033[0m\n\nTargets:\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ \
	      { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\n"

# ── Internal helpers ──────────────────────────────────────────────────────────

# Fail with a helpful message when a required env var is absent.
# Usage: @$(call require_env,VAR_NAME)
define require_env
	@if [ -z "$${$(1)}" ]; then \
		echo ""; \
		echo "  Error: $(1) is not set."; \
		echo "  Copy .env.example → .env, fill in your values, then run:"; \
		echo "    export \$$(grep -v '^#' .env | xargs)"; \
		echo ""; \
		exit 1; \
	fi
endef
