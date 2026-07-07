# Amina Travel — Docker workflow.
# Run `make` or `make help` to list targets.

COMPOSE      := docker compose
APP_PROFILE  := --profile app
API_URL      := http://localhost:5080

.DEFAULT_GOAL := help

.PHONY: help init up infra build rebuild down stop clean logs logs-api logs-web ps restart test env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if missing
	@test -f .env || (cp .env.example .env && echo "Created .env from .env.example")

init: env ## First run: build images and start the whole stack in Docker, then health-check
	$(COMPOSE) $(APP_PROFILE) up -d --build
	@echo "Waiting for the API to become healthy..."
	@for i in $$(seq 1 30); do \
		if curl -fs $(API_URL)/health >/dev/null 2>&1; then \
			echo "API is up:"; curl -s $(API_URL)/health; echo; \
			echo "→ Web:  http://localhost:3000"; \
			echo "→ API:  $(API_URL)/swagger"; \
			exit 0; \
		fi; \
		sleep 2; \
	done; \
	echo "API did not respond in time — check 'make logs-api'"; exit 1

up: env ## Start the whole stack (infra + api + web) in Docker
	$(COMPOSE) $(APP_PROFILE) up -d

infra: env ## Start only backing services (postgres, redis, opensearch, rabbitmq)
	$(COMPOSE) up -d

build: ## Build the api and web images
	$(COMPOSE) $(APP_PROFILE) build

rebuild: ## Rebuild images from scratch and restart
	$(COMPOSE) $(APP_PROFILE) build --no-cache
	$(COMPOSE) $(APP_PROFILE) up -d

down: ## Stop and remove containers
	$(COMPOSE) $(APP_PROFILE) down

stop: ## Stop containers without removing them
	$(COMPOSE) $(APP_PROFILE) stop

clean: ## Stop everything and delete volumes (DESTROYS local data)
	$(COMPOSE) $(APP_PROFILE) down -v --remove-orphans

logs: ## Tail logs for all services
	$(COMPOSE) $(APP_PROFILE) logs -f

logs-api: ## Tail API logs
	$(COMPOSE) logs -f api

logs-web: ## Tail web logs
	$(COMPOSE) logs -f web

ps: ## Show container status
	$(COMPOSE) $(APP_PROFILE) ps

restart: ## Restart api and web
	$(COMPOSE) $(APP_PROFILE) restart api web

test: ## Run backend unit tests (on host)
	cd backend && dotnet test
