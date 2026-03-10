#!/usr/bin/env bash
set -euo pipefail

# Start OpenClaw gateway in Docker with Control UI access via SSH tunnel
# This script ensures proper configuration for accessing the Control UI through an SSH tunnel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
COMPOSE_OVERRIDE="$SCRIPT_DIR/docker-compose.override.yml"

# Build compose command with override if it exists
if [[ -f "$COMPOSE_OVERRIDE" ]]; then
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE"
else
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
fi

# Configuration with defaults
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-openclaw:local}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

fail() {
  log_error "$*"
  exit 1
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    fail "Docker is not installed. Please install Docker first."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker Compose is not available. Please ensure Docker Compose is installed."
  fi

  if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is not running or you don't have permission to access it."
  fi
}

ensure_directories() {
  mkdir -p "$OPENCLAW_CONFIG_DIR"
  mkdir -p "$OPENCLAW_WORKSPACE_DIR"
  # Create standard subdirectories
  mkdir -p "$OPENCLAW_CONFIG_DIR/identity"
  mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/agent"
  mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/sessions"

  # Create default exec-approvals.json if it doesn't exist
  local exec_approvals_file="$OPENCLAW_CONFIG_DIR/exec-approvals.json"
  if [[ ! -f "$exec_approvals_file" ]]; then
    log_info "Creating default exec-approvals.json..."
    cat > "$exec_approvals_file" << 'EXECJSON'
{
  "version": 1,
  "default": {
    "security": "allowlist",
    "ask": "on-miss"
  },
  "agents": {
    "*": {
      "allowlist": [
        "ls", "cat", "head", "tail", "grep", "jq", "cut", "awk", "sed",
        "wc", "sort", "uniq", "find", "df", "du", "ps", "curl", "git",
        "docker", "which", "pwd", "echo", "date", "hostname"
      ]
    }
  }
}
EXECJSON
    chmod 600 "$exec_approvals_file" 2>/dev/null || true
  fi
}

get_config_value() {
  local key="$1"
  local config_file="$OPENCLAW_CONFIG_DIR/openclaw.json"

  if [[ ! -f "$config_file" ]]; then
    echo "null"
    return
  fi

  # Try using python3 first, then node, then jq
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
import sys
try:
    with open('$config_file', 'r') as f:
        cfg = json.load(f)
    keys = '$key'.split('.')
    val = cfg
    for k in keys:
        if isinstance(val, dict) and k in val:
            val = val[k]
        else:
            print('null')
            sys.exit(0)
    print(json.dumps(val))
except Exception:
    print('null')
"
  elif command -v node >/dev/null 2>&1; then
    node -e "
const fs = require('fs');
try {
  const cfg = JSON.parse(fs.readFileSync('$config_file', 'utf8'));
  const keys = '$key'.split('.');
  let val = cfg;
  for (const k of keys) {
    if (val && typeof val === 'object' && k in val) {
      val = val[k];
    } else {
      console.log('null');
      process.exit(0);
    }
  }
  console.log(JSON.stringify(val));
} catch {
  console.log('null');
}
"
  elif command -v jq >/dev/null 2>&1; then
    jq -r ".$key // null" "$config_file" 2>/dev/null || echo "null"
  else
    echo "null"
  fi
}

ensure_allowed_origins() {
  # Skip if binding to loopback only
  if [[ "$OPENCLAW_GATEWAY_BIND" == "loopback" ]]; then
    log_info "Gateway bound to loopback - Control UI origin check is lenient"
    return 0
  fi

  # The origin for SSH tunnel access (localhost forwarded to the gateway)
  local tunnel_origin="http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
  local current_origins

  current_origins="$(get_config_value "gateway.controlUi.allowedOrigins")"

  # Check if already configured
  if [[ "$current_origins" != "null" && "$current_origins" != "[]" && -n "$current_origins" ]]; then
    if echo "$current_origins" | grep -q "127.0.0.1"; then
      log_info "Control UI allowedOrigins already configured: $current_origins"
      return 0
    fi
  fi

  log_info "Setting Control UI allowedOrigins for SSH tunnel access..."

  # Set the allowed origins using the CLI container
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli \
    config set gateway.controlUi.allowedOrigins "[\"$tunnel_origin\"]" --strict-json >/dev/null 2>&1 || {
    log_warn "Could not set allowedOrigins automatically. You may need to set it manually."
    return 0
  }

  log_success "Set gateway.controlUi.allowedOrigins to: [\"$tunnel_origin\"]"
}

ensure_exec_config() {
  local exec_host
  exec_host="$(get_config_value "tools.exec.host")"

  # Skip if already configured
  if [[ "$exec_host" != "null" && -n "$exec_host" ]]; then
    log_info "Exec tool already configured: host=$exec_host"
    return 0
  fi

  log_info "Configuring exec tool for Docker environment..."

  # Configure exec for gateway host execution with allowlist security
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli \
    config set tools.exec.host gateway >/dev/null 2>&1 || {
    log_warn "Could not set exec.host"
  }

  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli \
    config set tools.exec.security allowlist >/dev/null 2>&1 || {
    log_warn "Could not set exec.security"
  }

  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli \
    config set tools.exec.ask on-miss >/dev/null 2>&1 || {
    log_warn "Could not set exec.ask"
  }

  log_success "Exec tool configured for gateway execution with allowlist security"
}

fix_permissions() {
  log_info "Fixing directory permissions..."

  # Run a temporary container to fix permissions for the node user (uid 1000)
  $COMPOSE_CMD run --rm --user root --entrypoint sh openclaw-cli -c \
    'find /home/node/.openclaw -xdev -exec chown node:node {} + 2>/dev/null || true' >/dev/null 2>&1 || {
    log_warn "Could not fix permissions automatically"
  }
}

start_gateway() {
  log_info "Starting OpenClaw gateway..."

  export OPENCLAW_CONFIG_DIR
  export OPENCLAW_WORKSPACE_DIR
  export OPENCLAW_GATEWAY_PORT
  export OPENCLAW_GATEWAY_BIND
  export OPENCLAW_IMAGE

  # Pull or build image if needed
  if [[ "$OPENCLAW_IMAGE" != "openclaw:local" ]]; then
    log_info "Pulling image: $OPENCLAW_IMAGE"
    docker pull "$OPENCLAW_IMAGE" || log_warn "Could not pull image, will try to use local"
  else
    # Check if image needs building (has override build config or image doesn't exist)
    if [[ -f "$SCRIPT_DIR/docker-compose.override.yml" ]] || ! docker image inspect openclaw:local >/dev/null 2>&1; then
      log_info "Building image with custom packages (vim, jq, etc.)..."
      $COMPOSE_CMD build openclaw-gateway
    fi
  fi

  # Start the gateway
  $COMPOSE_CMD up -d openclaw-gateway

  # Wait for health check
  log_info "Waiting for gateway to be healthy..."
  local attempts=0
  local max_attempts=30

  while [[ $attempts -lt $max_attempts ]]; do
    if $COMPOSE_CMD ps openclaw-gateway | grep -q "healthy"; then
      log_success "Gateway is healthy!"
      return 0
    fi
    if $COMPOSE_CMD ps openclaw-gateway | grep -q "unhealthy"; then
      fail "Gateway is unhealthy. Check logs with: docker compose -f $COMPOSE_FILE logs openclaw-gateway"
    fi
    sleep 1
    ((attempts++)) || true
  done

  log_warn "Gateway health check timed out, but it may still be starting..."
}

print_access_info() {
  local server_ip
  server_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')"

  echo ""
  echo "=========================================="
  log_success "OpenClaw Gateway is running!"
  echo "=========================================="
  echo ""
  echo -e "${BLUE}Access via SSH Tunnel:${NC}"
  echo "  1. From your local machine, create a tunnel:"
  echo ""
  echo -e "     ${GREEN}ssh -L 18789:localhost:18789 user@${server_ip}${NC}"
  echo ""
  echo "  2. Then open the Control UI in your browser:"
  echo ""
  echo -e "     ${GREEN}http://localhost:18789${NC}"
  echo ""
  echo -e "${BLUE}Direct Access (if on same network):${NC}"
  echo "  http://${server_ip}:${OPENCLAW_GATEWAY_PORT}"
  echo ""
  echo -e "${BLUE}Configuration:${NC}"
  echo "  Config directory: $OPENCLAW_CONFIG_DIR"
  echo "  Workspace directory: $OPENCLAW_WORKSPACE_DIR"
  echo "  Exec tool: enabled (gateway host, allowlist security)"
  echo ""
  echo -e "${BLUE}Useful Commands:${NC}"
  if [[ -f "$COMPOSE_OVERRIDE" ]]; then
    echo "  View logs:     docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE logs -f openclaw-gateway"
    echo "  Stop gateway:  docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE down"
    echo "  CLI commands:  docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE run --rm openclaw-cli <command>"
  else
    echo "  View logs:     docker compose -f $COMPOSE_FILE logs -f openclaw-gateway"
    echo "  Stop gateway:  docker compose -f $COMPOSE_FILE down"
    echo "  CLI commands:  docker compose -f $COMPOSE_FILE run --rm openclaw-cli <command>"
  fi
  echo ""
  echo -e "${BLUE}First-time Setup:${NC}"
  if [[ -f "$COMPOSE_OVERRIDE" ]]; then
    echo "  1. Check channel status:  docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE run --rm openclaw-cli channels status"
    echo "  2. Add a channel (e.g., Discord):"
    echo "     docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE run --rm openclaw-cli channels add --channel discord --token <your-token>"
  else
    echo "  1. Check channel status:  docker compose -f $COMPOSE_FILE run --rm openclaw-cli channels status"
    echo "  2. Add a channel (e.g., Discord):"
    echo "     docker compose -f $COMPOSE_FILE run --rm openclaw-cli channels add --channel discord --token <your-token>"
  fi
  echo ""
}

main() {
  echo "=========================================="
  echo "  OpenClaw Docker Startup Script"
  echo "=========================================="
  echo ""

  check_docker
  ensure_directories
  ensure_allowed_origins
  ensure_exec_config
  fix_permissions
  start_gateway
  print_access_info
}

# Handle arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Start OpenClaw gateway in Docker with Control UI access via SSH tunnel."
  echo ""
  echo "Environment Variables:"
  echo "  OPENCLAW_CONFIG_DIR      Config directory (default: ~/.openclaw)"
  echo "  OPENCLAW_WORKSPACE_DIR   Workspace directory (default: ~/.openclaw/workspace)"
  echo "  OPENCLAW_GATEWAY_PORT    Gateway port (default: 18789)"
  echo "  OPENCLAW_GATEWAY_BIND    Bind address: loopback|lan (default: lan)"
  echo "  OPENCLAW_IMAGE           Docker image (default: openclaw:local)"
  echo ""
  echo "Examples:"
  echo "  $0                           # Start with defaults"
  echo "  OPENCLAW_GATEWAY_PORT=8080 $0  # Use custom port"
  echo ""
  exit 0
fi

main "$@"
