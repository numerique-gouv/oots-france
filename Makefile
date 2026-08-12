COMPOSE = docker compose
# `-T` and not a bare `exec`: without it Docker demands a terminal, and the CI
# runner has none. It costs nothing where one exists.
IN_WEB = $(COMPOSE) exec -T web bundle exec

.DEFAULT_GOAL = help
.PHONY: help up down test lint lint-fix e2e schematron console shell logs

help:
	@grep -hE '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | expand -t 14

up: ## Run the application: server, background worker, database, gateway
	$(COMPOSE) up web worker

down: ## Stop everything, keeping the volumes
	$(COMPOSE) down

test: ## RuboCop then RSpec, in Docker
	$(COMPOSE) up test

lint: ## RuboCop alone
	$(IN_WEB) rubocop

lint-fix: ## RuboCop, autocorrecting what is safe to autocorrect
	$(IN_WEB) rubocop -a

e2e: ## Cucumber through a real Domibus — needs the stack up, see docs/test_e2e.md
	$(IN_WEB) cucumber --profile bout_en_bout

schematron: ## The messages we produce, against the rules published with the TDD
	scripts/valideSchematron.sh

console: ## A Rails console in the running server
	$(COMPOSE) exec web bundle exec rails console

shell: ## A shell in the running server
	$(COMPOSE) exec web bash

logs: ## Follow the server and worker logs
	$(COMPOSE) logs -f web worker
