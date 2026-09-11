IMAGE := ghcr.io/cameronsjo/immich-backup
TAG := latest

.PHONY: help build run test test-reaping clean

## Show available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //' | head -1; \
	grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

## Build the container image
build: ## Build Docker image
	docker build -t $(IMAGE):$(TAG) .

## Run locally for testing
run: ## Run container (requires .env file)
	docker run --rm --env-file .env -v /tmp/immich-backup-test:/data $(IMAGE):$(TAG)

## Lint shell scripts
test: ## Run shell regression tests and lint scripts
	./tests/backup.sh
	shellcheck scripts/*.sh tests/*.sh

## Verify repeated health probes do not leave zombie CGI children
test-reaping:
	./tests/test-health-reaping.sh

## Remove built image
clean: ## Remove Docker image
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true
