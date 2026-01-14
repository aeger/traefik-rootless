SHELL := /usr/bin/env bash

.PHONY: help lint run stop restart logs status

help:
	@echo "Targets:"
	@echo "  make lint     - run shellcheck locally (if installed)"
	@echo "  make run      - start/recreate Traefik"
	@echo "  make stop     - stop Traefik container"
	@echo "  make restart  - stop then run"
	@echo "  make logs     - tail Traefik logs"
	@echo "  make status   - show podman container status"

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed"; exit 1; }
	shellcheck -x traefik-run.sh

run:
	chmod +x traefik-run.sh
	./traefik-run.sh

stop:
	podman rm -f traefik 2>/dev/null || true

restart: stop run

logs:
	podman logs -f traefik

status:
	podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
