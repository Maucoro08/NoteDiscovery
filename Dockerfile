# Global build arg — override with: docker build --build-arg PYTHON_VERSION=3.12 .
ARG PYTHON_VERSION=3.11

# Stage 1: Minify frontend assets
FROM node:20-alpine AS minifier

WORKDIR /build

# Install minification tools (esbuild for JS, html-minifier-terser for HTML)
RUN npm install -g esbuild html-minifier-terser

# Copy frontend files
COPY frontend/ ./frontend/

# Minify JavaScript (esbuild is ~100x faster than terser)
RUN esbuild frontend/app.js --minify --outfile=frontend/app.js --allow-overwrite && \
    esbuild frontend/sw.js --minify --outfile=frontend/sw.js --allow-overwrite

# Minify HTML files (handles inline CSS and JS too)
RUN html-minifier-terser \
    --collapse-whitespace \
    --remove-comments \
    --remove-redundant-attributes \
    --minify-css true \
    --minify-js true \
    -o frontend/index.html \
    frontend/index.html && \
    html-minifier-terser \
    --collapse-whitespace \
    --remove-comments \
    --minify-css true \
    --minify-js true \
    -o frontend/login.html \
    frontend/login.html

# Stage 2: Download browser libraries so the runtime needs no CDN
FROM python:${PYTHON_VERSION}-slim AS vendor

WORKDIR /build

COPY scripts/vendor_assets.py scripts/vendor_lock.json ./scripts/
RUN python scripts/vendor_assets.py --dest /vendor

# Stage 3: Install Python dependencies
FROM python:${PYTHON_VERSION}-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 4: Final minimal image
FROM python:${PYTHON_VERSION}-slim

# Create a non-root user for security
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --no-create-home appuser

WORKDIR /app

# Copy only installed packages (no pip cache, no build artifacts)
COPY --from=builder /install /usr/local

# Copy minified frontend from minifier stage
COPY --from=minifier /build/frontend ./frontend

# Browser libraries, with their licence texts and notices
COPY --from=vendor /vendor ./frontend/vendor

# Copy application files
COPY backend ./backend
COPY mcp_server ./mcp_server
COPY config.yaml .
COPY VERSION .
COPY run.py .
COPY pyproject.toml .
COPY plugins ./plugins
COPY themes ./themes
COPY locales ./locales

# Create data directory and set ownership
RUN mkdir -p data && chown -R appuser:appuser /app

# Declare data as a volume so notes persist across container restarts
VOLUME ["/app/data"]

# Drop to non-root user
USER appuser

# Expose port (default, can be overridden)
EXPOSE 8000

# Set default port (can be overridden via environment variable)
ENV PORT=8000

# Health check (uses PORT env var)
HEALTHCHECK --interval=60s --timeout=3s --start-period=15s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.getenv(\"PORT\", \"8000\")}/health')"

# Run the application (shell form to allow environment variable expansion)
# Use exec to replace shell with uvicorn (receives SIGTERM directly for graceful shutdown)
CMD exec uvicorn backend.main:app --host 0.0.0.0 --port $PORT --timeout-graceful-shutdown 2
