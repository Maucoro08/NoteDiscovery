# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Stack
- **Backend**: Python 3.10+ FastAPI app (`backend/`) + vanilla JS frontend (`frontend/`) — no JS build step
- **Entry point**: `python run.py` (auto-installs deps and downloads frontend vendor assets on first run)
- **Frontend vendor assets**: downloaded at runtime from CDN by `scripts/vendor_assets.py`; not committed. Run `python scripts/vendor_assets.py` if the UI fails to load.

## Commands
```bash
# Run the app (dev mode with --reload)
python run.py

# Install Python deps
pip install -r requirements.txt

# Re-download/fix missing frontend libraries
python scripts/vendor_assets.py

# Run tests (no test files exist yet; framework is configured)
pip install -e ".[dev]"
pytest
# Single test: pytest path/to/test_file.py::test_function_name
```

## Architecture — Critical Patterns

### All authenticated API routes must use `api_router`, not `app` directly
Routes added to `app.get(...)` bypass the `require_auth` dependency. Use `api_router` (defined in `backend/main.py`) for any endpoint that should be protected. The few intentionally unauthenticated endpoints (e.g. `/api/locales`, `/api/themes/{id}`) are registered on `app` directly with a comment explaining why.

### NoteIndex is process-memory only — always invalidate caches after mutations
`note_index` in `backend/note_index.py` is rebuilt lazily on first `/api/notes` call after process start. After every mutation (save/delete/move), call `_scan_cache_invalidate()` from `backend/utils.py` **and** the appropriate `note_index.on_*` facade.

### Logger convention
Every backend module uses `logger = logging.getLogger("uvicorn.error")` — not `logging.getLogger(__name__)`. This routes all log output through uvicorn's log handler.

### Plugin system
- Loaded from `config.storage.plugins_dir` (default `./plugins/`), NOT from `plugins/contrib/`
- Contrib plugins (`plugins/contrib/`) ship with the repo but are never auto-loaded; users copy them into `plugins/` to install
- Each plugin is a single `.py` file exposing a `Plugin` class with optional `setup(ctx)`, `get_routes()`, and `on_*` hook methods
- Valid hooks are defined in `HOOK_SPECS` in `backend/plugins.py`; unrecognised `on_*` methods trigger a warning

### File storage conventions
- Uploaded media → `{note_folder}/_attachments/{name}-{timestamp}{ext}`
- Drawing PNGs → `{content_folder}/drawing-{timestamp}.png` (next to `.md` files, NOT in `_attachments`)
- Note templates → `{notes_dir}/_templates/*.md`

### Security: always use `validate_path_security(notes_dir, path)` for user-supplied paths
This prevents path traversal. Every file-access endpoint calls it before touching the filesystem.

### Config and version
- `config.yaml` at repo root is the primary config; all keys can be overridden by env vars (see comments in `config.yaml`)
- `VERSION` file at repo root is the single source of truth for the app version — not `pyproject.toml`

## Code Style
- Python: PEP 8, type hints on public functions, docstrings on public functions/classes
- `from __future__ import annotations` is used in `note_index.py` for forward references
- ES6+ vanilla JS in `frontend/app.js` — no framework, no transpiler
- Swagger UI lives at `/api` (not `/docs`); ReDoc is disabled
