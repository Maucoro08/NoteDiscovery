# Project Documentation Rules (Non-Obvious Only)

- **Swagger UI is at `/api`**, not `/docs`. ReDoc is disabled. FastAPI's `docs_url='/api'` overrides the default.
- **`plugins/contrib/`** ships with the repo but is never loaded by the app. It is a gallery of user-contributed plugins that users install by copying to `plugins/`. The `documentation/PLUGINS.md` file documents the plugin *system*, not the contrib directory.
- **`frontend/vendor/`** is absent from the repo — it is populated at runtime by `scripts/vendor_assets.py`. Documentation about "running locally" always requires this download step first.
- **NoteIndex is not persistent** — it lives in process memory and rebuilds (~1–3s on a 10K-note vault) on the first `/api/notes` request after each process start. There is no database.
- **Config priority for every setting**: env var → `config.yaml` → code default. The comments in `config.yaml` show each env var name.
- **`VERSION` file** (repo root, one line) is the canonical version source, not `pyproject.toml`.
- **Authentication is off by default** in `config.yaml`. When enabled, the default password is literally `"admin"`.
