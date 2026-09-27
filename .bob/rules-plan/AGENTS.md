# Project Architecture Rules (Non-Obvious Only)

- **Two-layer cache**: `_tag_cache`/`_links_cache` (per-file, mtime-keyed) and `_SCAN_WALK_CACHE` (1-second TTL, per-scan) in `backend/utils.py`. Both sit in front of the `NoteIndex` in `backend/note_index.py`. Any plan touching file mutations must account for invalidating all three layers.
- **NoteIndex is the system of record** for tags, backlinks, search, and graph. `backend/utils.py` functions are thin wrappers that call `note_index.*`. Heavy data queries must go through the index, not re-scan files.
- **Search index is lazily built**: `note_index.ensure_search_index(notes_dir)` is called inside `search_notes()`. The inverted index is populated on the first `/api/search` call, not at startup.
- **Parallel extraction cutoff**: Tag+link extraction is parallelized only when `>= 50` markdown files are present (`_PARALLEL_CUTOFF` in `note_index.py`, same threshold in `utils.py`). Plans adding bulk operations should respect this boundary.
- **Plugin routes mount at `/api/plugins/<plugin_id>`** — not configurable. `PluginManager` in `backend/plugins.py` handles loading, error isolation, and hook dispatch.
- **No JS build step / no bundler**: `frontend/app.js` is single-file vanilla JS loaded directly by the browser. Any plan introducing a build step would require significant CI/deployment changes.
- **Frontend–backend contract**: The frontend reads `/api/config` at startup for feature flags (`demoMode`, `autosaveDelayMs`, `sharePublicOrigin`, etc.). New config values intended for the frontend must be added there.
- **Rate limiting is demo-only**: `slowapi` limiter is active only when `DEMO_MODE=true`. In normal deployments `DummyLimiter` is used and `@limiter.limit(...)` decorators are no-ops.
