.PHONY: ubuntu-deps setup run run-web lint format format-check test check-all install install-gui clean build-linux serve-docs build-docs

PYTHON := python3
VENV := .venv
PIP := $(VENV)/bin/pip
BIN := $(VENV)/bin

# ── Ubuntu System Dependencies ────────────────────────────────────────────────

ubuntu-deps:
	sudo apt update
	sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential make git

# ── First-time Setup ──────────────────────────────────────────────────────────

setup:
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -e ".[dev,web,gui]"
	@echo ""
	@echo "Setup complete!"
	@echo "Desktop application : make run"
	@echo "Web interface       : make run-web"
	@echo "Run tests           : make test"

# ── Run ───────────────────────────────────────────────────────────────────────

# Launch desktop GUI
run:
	$(BIN)/docfinder-gui

# Launch web interface
run-web:
	$(BIN)/docfinder web

# ── Installation ──────────────────────────────────────────────────────────────

# Install without GUI
install:
	$(PIP) install -e ".[dev,web]"

# Install with GUI
install-gui:
	$(PIP) install -e ".[dev,web,gui]"

# ── Code Quality ──────────────────────────────────────────────────────────────

lint:
	$(BIN)/ruff check src/ tests/

format-check:
	$(BIN)/ruff format --check src/ tests/

format:
	$(BIN)/ruff format src/ tests/

# ── Testing ───────────────────────────────────────────────────────────────────

test:
	$(BIN)/pytest -v --cov=docfinder --cov-report=term

check-all: lint format-check test
	@echo "All checks passed!"

# ── Linux Build ───────────────────────────────────────────────────────────────

# Build Linux AppImage
build-linux:
	chmod +x scripts/build-linux.sh
	./scripts/build-linux.sh

# ── Documentation ─────────────────────────────────────────────────────────────

serve-docs:
	$(PIP) install -e ".[docs]"
	$(BIN)/mkdocs serve

build-docs:
	$(PIP) install -e ".[docs]"
	$(BIN)/mkdocs build

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean:
	rm -rf build/ dist/ *.egg-info htmlcov/ .coverage coverage.xml .pytest_cache/
	rm -rf resources/DocFinder.iconset resources/DocFinder.icns resources/DocFinder.ico
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
