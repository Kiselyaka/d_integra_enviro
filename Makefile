COMPOSE = docker compose

.PHONY: up down build logs reset test

up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down --remove-orphans

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

reset:
	$(COMPOSE) down --volumes --remove-orphans
	$(COMPOSE) up --build -d

test:
	cd ../integration-platform/backend && python -m pytest
	cd ../demo-business-systems/mini-shop && python -m pytest
	cd ../demo-business-systems/crm && python -m pytest

