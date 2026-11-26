.PHONY: ubuntu-deps setup run run-web lint format format-check test check-all install install-gui clean build-linux serve-docs build-docs

VENV := .venv
ifeq ($(OS),Windows_NT)
PYTHON ?= python
VENV_BIN := $(VENV)/Scripts
VENV_PYTHON := $(VENV_BIN)/python.exe
DOCFINDER := $(VENV_BIN)/docfinder.exe
DOCFINDER_GUI := $(VENV_BIN)/docfinder-gui.exe
else
PYTHON ?= python3
VENV_BIN := $(VENV)/bin
VENV_PYTHON := $(VENV_BIN)/python
DOCFINDER := $(VENV_BIN)/docfinder
DOCFINDER_GUI := $(VENV_BIN)/docfinder-gui
endif
PIP := $(VENV_PYTHON) -m pip

# ── Ubuntu System Dependencies ────────────────────────────────────────────────

ubuntu-deps:
	sudo apt update
	sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential make git \
		pkg-config

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
	$(DOCFINDER_GUI)

# Launch web interface
run-web:
	$(DOCFINDER) web

# ── Installation ──────────────────────────────────────────────────────────────

# Install without GUI
install:
	$(PIP) install -e ".[dev,web]"

# Install with GUI
install-gui:
	$(PIP) install -e ".[dev,web,gui]"

# ── Code Quality ──────────────────────────────────────────────────────────────

lint:
	$(VENV_PYTHON) -m ruff check src/ tests/

format-check:
	$(VENV_PYTHON) -m ruff format --check src/ tests/

format:
	$(VENV_PYTHON) -m ruff format src/ tests/

# ── Testing ───────────────────────────────────────────────────────────────────

test:
	$(VENV_PYTHON) -m pytest -v --cov=docfinder --cov-report=term

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
	$(VENV_PYTHON) -m mkdocs serve

build-docs:
	$(PIP) install -e ".[docs]"
	$(VENV_PYTHON) -m mkdocs build

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean:
	$(PYTHON) -c "import shutil; from pathlib import Path; paths = ['build', 'dist', 'htmlcov', '.pytest_cache', 'resources/DocFinder.iconset', 'resources/DocFinder.icns', 'resources/DocFinder.ico']; [shutil.rmtree(p) if p.is_dir() else p.unlink() for name in paths for p in [Path(name)] if p.exists()]; [p.unlink() for name in ['.coverage', 'coverage.xml'] for p in [Path(name)] if p.is_file()]; [shutil.rmtree(p) for p in Path('.').rglob('__pycache__') if p.is_dir()]; [p.unlink() for p in Path('.').rglob('*.pyc') if p.is_file()]; [shutil.rmtree(p) for p in Path('.').glob('*.egg-info') if p.is_dir()]"
