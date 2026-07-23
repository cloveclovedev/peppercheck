# Local development helpers for the peppercheck Go backend.
# Requires docker + go. Atlas is pinned to v1.2.0 (see README).

.PHONY: help up down down-v logs ps backup test fmt vet

help: ## Show available targets
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-9s %s\n", $$1, $$2}'

up: ## Start the core stack (creates .env from the template if missing)
	[ -f .env ] || cp .env.example .env
	docker compose up -d --build

down: ## Stop the stack (keep volumes)
	docker compose down

down-v: ## Stop and remove volumes (clears Postgres data + the local WAL archive)
	docker compose --profile backup down -v

logs: ## Follow stack logs
	docker compose logs -f

ps: ## Show stack status
	docker compose ps

backup: ## Start the opt-in backup profile (needs AGE_RECIPIENT in .env)
	docker compose --profile backup up -d --build backup

test: ## Run Go tests (needs DATABASE_URL, or run `make up` first)
	go test -race -p 1 ./...

fmt: ## Format Go code
	gofmt -w .

vet: ## Run go vet
	go vet ./...
