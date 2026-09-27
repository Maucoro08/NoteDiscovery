# Project Coding Rules (Non-Obvious Only)

- **Route authentication**: Add new API endpoints to `api_router` (prefix `/api`, auth applied) in `backend/main.py`. Only add to `app` directly if explicitly unauthenticated — document why with a comment.
- **Cache invalidation after mutations**: Every write path (save, delete, move, rename) must call `_scan_cache_invalidate()` from `backend/utils.py` AND the relevant `note_index.on_*` facade. Forgetting either leaves stale data in the in-memory index.
- **Logger**: Use `logger = logging.getLogger("uvicorn.error")` — never `__name__`. All modules follow this.
- **Path security**: Any user-supplied file path must be validated with `validate_path_security(notes_dir, path)` before filesystem access. Returns `bool`.
- **Error responses in production**: Use `safe_error_message(e, "user message")` (defined in `backend/main.py`) instead of `str(e)`. It returns full detail only when `server.debug` is true.
- **Frontend assets are not committed**: `frontend/vendor/` is gitignored and downloaded by `scripts/vendor_assets.py`. `run.py` auto-calls this on first start. If adding a new vendor library, update `scripts/vendor_assets.py` and `scripts/vendor_lock.json`.
- **Plugin hook names**: Must exactly match keys in `HOOK_SPECS` dict in `backend/plugins.py`. Typos are warned but silently ignored.
- **`__APP_NAME__` / `__APP_VERSION__` placeholders**: `index.html`, `login.html`, `manifest.json`, and `sw.js` use these at runtime — do not hardcode the app name or version in HTML/JS files.
- **Drawing files naming**: Must be `drawing-{timestamp}.png` — code in `backend/utils.py` and the `PUT /api/media/` endpoint check for this exact pattern.
