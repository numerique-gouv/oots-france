COMPOSE = docker compose
# `-T` and not a bare `exec`: without it Docker demands a terminal, and the CI
# runner has none. It costs nothing where one exists.
IN_WEB = $(COMPOSE) exec -T web bundle exec

.DEFAULT_GOAL = help
.PHONY: help setup up domibus down test lint lint-fix e2e schematron console shell logs logs-domibus

help:
	@grep -hE '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | expand -t 16

setup: ## Install from a fresh clone: env files, databases, configured gateway
	scripts/setup.sh

up: ## Run the application: server, background worker, database, gateway
	$(COMPOSE) up web worker

# Same order as scripts/setup.sh, and for the same reasons: `depends_on` only
# orders container startup, so the gateway would meet a database still creating
# itself; and the daemon cannot create the bind mount under a VM with a shared
# filesystem. The gateway logs nothing to the terminal (logging driver `none`),
# so a foreground `up` would look hung for the minutes Tomcat spends deploying.
domibus: ## Run the gateway alone, and wait until its console answers
	mkdir -p domibus
	$(COMPOSE) up --detach mysql
	scripts/ci/wait_for_mysql.sh
	$(COMPOSE) up --detach domibus
	scripts/ci/wait_for_domibus.sh

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
	scripts/validate_schematron.sh

console: ## A Rails console in the running server
	$(COMPOSE) exec web bundle exec rails console

shell: ## A shell in the running server
	$(COMPOSE) exec web bash

logs: ## Follow the server and worker logs
	$(COMPOSE) logs -f web worker

logs-domibus: ## Follow the gateway logs, which `docker compose logs` cannot show
	scripts/domibus_logs.sh
