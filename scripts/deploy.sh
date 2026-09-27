#!/usr/bin/env bash
# deploy.sh — Clone a GitHub repo and start it with Docker Compose
#
# Usage:
#   bash deploy.sh [options] [github-url] [target-directory]
#
# Options:
#   -b, --build-only   Build the Docker image and write a production-ready
#                      docker-compose.yml (no build: key, image: only).
#                      Containers are NOT started. Ideal for Portainer stacks.
#
# Examples:
#   bash deploy.sh https://github.com/user/NoteDiscovery
#   bash deploy.sh https://github.com/user/NoteDiscovery ./myapp
#   bash deploy.sh --build-only https://github.com/user/NoteDiscovery
#   bash deploy.sh --build-only          # use repo root (script inside scripts/)

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────

BUILD_ONLY=false
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build-only) BUILD_ONLY=true; shift ;;
        -*) die "Unknown option: $1" ;;
        *)  POSITIONAL+=("$1"); shift ;;
    esac
done

GITHUB_URL="${POSITIONAL[0]:-}"
TARGET_DIR="${POSITIONAL[1]:-}"

# If no URL given, assume we are already inside the repo (script lives in scripts/)
if [[ -z "$GITHUB_URL" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TARGET_DIR="$(dirname "$SCRIPT_DIR")"
    info "No URL provided — using repo root: $TARGET_DIR"
# Derive repo name from URL if no target directory was given
elif [[ -z "$TARGET_DIR" ]]; then
    REPO_NAME="$(basename "$GITHUB_URL" .git)"
    TARGET_DIR="./${REPO_NAME}"
fi

# ── Dependency checks ─────────────────────────────────────────────────────────

for cmd in git docker; do
    command -v "$cmd" &>/dev/null || die "'$cmd' is not installed or not in PATH."
done

# Prefer 'docker compose' (v2 plugin) over 'docker-compose' (v1 standalone)
if docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    die "Neither 'docker compose' (v2) nor 'docker-compose' (v1) found."
fi

# ── Clone ─────────────────────────────────────────────────────────────────────

if [[ -z "$GITHUB_URL" ]]; then
    info "Skipping clone — working with existing directory '$TARGET_DIR'."
elif [[ -d "$TARGET_DIR/.git" ]]; then
    warn "Directory '$TARGET_DIR' already contains a git repo — pulling latest instead of cloning."
    git -C "$TARGET_DIR" pull
else
    info "Cloning $GITHUB_URL → $TARGET_DIR"
    git clone "$GITHUB_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

# ── Validate docker-compose.yml exists ───────────────────────────────────────

if [[ ! -f "docker-compose.yml" && ! -f "docker-compose.yaml" && ! -f "compose.yml" && ! -f "compose.yaml" ]]; then
    die "No docker-compose.yml found in '$TARGET_DIR'. Is this the right repo?"
fi

# ── Optional: create data directory so the volume mount doesn't fail ──────────

if [[ ! -d "data" ]]; then
    info "Creating ./data directory for persistent notes volume."
    mkdir -p data
fi

# ── Build & start ─────────────────────────────────────────────────────────────

# Use docker build directly so the build always works regardless of what
# docker-compose.yml contains (it may already be the production image-only version).
info "Building Docker image (notediscovery:local)..."
docker build -t notediscovery:local .

if [[ "$BUILD_ONLY" == true ]]; then
    info "Writing production docker-compose.yml (image-only, no build key)..."
    cat > docker-compose.yml << 'EOF'
services:
  notediscovery:
    image: notediscovery:local
    container_name: notediscovery
    ports:
      - "${PORT:-8000}:${PORT:-8000}"
    volumes:
      # Required: Your notes
      - ./data:/app/data
      # Optional: Uncomment to customize (file/folder must exist with content!)
      # - ./config.yaml:/app/config.yaml
      # - ./themes:/app/themes
      # - ./plugins:/app/plugins
      # - ./locales:/app/locales
    restart: unless-stopped
    user: "1000:1000"
    security_opt:
      - no-new-privileges:true
    environment:
      PORT: ${PORT:-8000}
      TZ: ${TZ:-UTC}
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "python", "-c", "import os, urllib.request; urllib.request.urlopen(f'http://localhost:{os.getenv(\"PORT\", \"8000\")}/health')"]
      interval: 60s
      timeout: 3s
      retries: 3
      start_period: 15s
EOF
    info "docker-compose.yml updated — ready for Portainer or 'docker compose up -d'."
    exit 0
fi

info "Starting containers..."
$COMPOSE up -d

# ── Status ────────────────────────────────────────────────────────────────────

info "Containers started. Current status:"
$COMPOSE ps

PORT="${PORT:-8000}"
info "App should be available at http://localhost:${PORT}"
info "To follow logs: $COMPOSE logs -f"
info "To stop:        $COMPOSE down"
