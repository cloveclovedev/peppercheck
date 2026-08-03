# Local development helpers for the peppercheck Go backend.
# Requires docker + go + atlas (pinned v1.2.0 — see README).
#
# NOTE: after pulling a change to the DB role/schema bootstrap
# (deploy/postgres/init/*), run `make reset` — Postgres init scripts only run on
# an EMPTY data dir, so an existing volume won't pick up new roles/schemas.

.PHONY: help up down down-v reset logs ps backup test fmt vet

# Override these when running backend tests from more than one worktree.
# scripts/worktree/dev.sh supplies isolated values automatically.
TEST_CONTAINER_NAME ?= pc-maketest
TEST_POSTGRES_PORT ?= 55432

help: ## Show available targets
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-9s %s\n", $$1, $$2}'

up: ## Start the core stack (creates .env if missing). Add BWS_PROJECT_ID=<id> to inject real dev secrets via Bitwarden Secrets Manager (see docs/development/bws-development.md)
	[ -f .env ] || cp .env.example .env
	@if [ -n "$(BWS_PROJECT_ID)" ]; then \
		scripts/bws-dev-up.sh "$(BWS_PROJECT_ID)"; \
	else \
		docker compose up -d --build; \
	fi

down: ## Stop the stack (keep volumes)
	docker compose down

down-v: ## Stop and remove volumes (clears Postgres data + the local WAL archive)
	docker compose --profile backup down -v

reset: down-v up ## Recreate from scratch (run after DB role/schema init changes)

logs: ## Follow stack logs
	docker compose logs -f

ps: ## Show stack status
	docker compose ps

backup: ## Start the opt-in backup profile (needs AGE_RECIPIENT in .env)
	docker compose --profile backup up -d --build backup

test: ## Run Go tests incl. DB integration on a throwaway Postgres (needs host atlas v1.2.0)
	@set -e; name="$(TEST_CONTAINER_NAME)"; port="$(TEST_POSTGRES_PORT)"; \
	docker rm -f $$name >/dev/null 2>&1 || true; \
	trap 'docker rm -f $$name >/dev/null 2>&1 || true' EXIT; \
	docker run --rm -d --name $$name -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=peppercheck -e POSTGRES_MIGRATOR_PASSWORD=m -e POSTGRES_APP_PASSWORD=a -e POSTGRES_BACKUP_PASSWORD=b -v "$$PWD/deploy/postgres/init:/docker-entrypoint-initdb.d:ro" -p 127.0.0.1:$$port:5432 postgres:17 -c archive_mode=off >/dev/null; \
	ready=; i=0; while [ $$i -lt 60 ]; do \
	  if docker exec $$name pg_isready -h 127.0.0.1 -U postgres -d peppercheck >/dev/null 2>&1; then ready=1; break; fi; \
	  docker ps -q -f name=$$name | grep -q . || { echo "test DB container exited during init:"; docker logs $$name 2>&1 | tail -20; exit 1; }; \
	  i=$$((i+1)); sleep 1; \
	done; \
	[ "$$ready" = 1 ] || { echo "test DB not ready after 60s"; exit 1; }; \
	dsn="postgres://peppercheck_migrator:m@127.0.0.1:$$port/peppercheck?sslmode=disable"; \
	app_dsn="postgres://peppercheck_app:a@127.0.0.1:$$port/peppercheck?sslmode=disable"; \
	atlas migrate apply --env local --url "$$dsn" --revisions-schema atlas >/dev/null; \
	DATABASE_URL="$$dsn" APP_DATABASE_URL="$$app_dsn" go test -race -p 1 -count=1 ./...

fmt: ## Format Go code
	gofmt -w .

vet: ## Run go vet
	go vet ./...
