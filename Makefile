.PHONY: up down smoke eval gate loadtest redteam lint test help

help:
	@echo "up down smoke eval gate loadtest redteam lint test"

up down smoke eval gate loadtest redteam:
	@echo TODO

lint:
	uv run ruff check .
	uv run ruff format --check .

test:
	uv run pytest
