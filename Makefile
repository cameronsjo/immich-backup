IMAGE := ghcr.io/cameronsjo/immich-backup
TAG := latest

.PHONY: help build run test clean

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
test: ## Check scripts with shellcheck
	shellcheck scripts/*.sh

## Remove built image
clean: ## Remove Docker image
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true
