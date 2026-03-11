#!/usr/bin/env bash
set -euo pipefail

# Backup OpenClaw configuration from Docker to local files
# This allows restoring the same configuration on another environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="${OPENCLAW_BACKUP_DIR:-$SCRIPT_DIR/openclaw-backup}"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
COMPOSE_OVERRIDE="$PROJECT_DIR/docker-compose.override.yml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

# Build compose command
if [[ -f "$COMPOSE_OVERRIDE" ]]; then
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE"
else
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Backing up OpenClaw configuration..."
log_info "Backup directory: $BACKUP_DIR"

# Backup main config
log_info "Exporting openclaw.json..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli \
  config get 2>/dev/null > "$BACKUP_DIR/openclaw.json" || {
  log_warn "Could not export full config, trying partial export..."
}

# Backup individual sections for easier restoration
log_info "Exporting agents configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get agents 2>/dev/null > "$BACKUP_DIR/agents.json" || true

log_info "Exporting tools configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get tools 2>/dev/null > "$BACKUP_DIR/tools.json" || true

log_info "Exporting skills configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get skills 2>/dev/null > "$BACKUP_DIR/skills.json" || true

log_info "Exporting models configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get models 2>/dev/null > "$BACKUP_DIR/models.json" || true

log_info "Exporting auth configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get auth 2>/dev/null > "$BACKUP_DIR/auth.json" || true

log_info "Exporting queue configuration..."
$COMPOSE_CMD run --rm \
  -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
  openclaw-cli config get messages.queue 2>/dev/null > "$BACKUP_DIR/queue.json" || true

# Backup exec-approvals.json
log_info "Copying exec-approvals.json..."
docker compose cp openclaw-gateway:/home/node/.openclaw/exec-approvals.json "$BACKUP_DIR/exec-approvals.json" 2>/dev/null || {
  log_warn "exec-approvals.json not found in container"
}

# Backup skills directory
log_info "Backing up custom skills..."
mkdir -p "$BACKUP_DIR/skills"
if docker compose exec openclaw-gateway test -d /app/skills 2>/dev/null; then
  docker compose cp openclaw-gateway:/app/skills/ "$BACKUP_DIR/" 2>/dev/null || true
fi

# Create a restore script
cat > "$BACKUP_DIR/restore.sh" << 'RESTORESCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Restore OpenClaw configuration from backup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PARENT_DIR/docker-compose.yml"
COMPOSE_OVERRIDE="$PARENT_DIR/docker-compose.override.yml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

# Build compose command
if [[ -f "$COMPOSE_OVERRIDE" ]]; then
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE -f $COMPOSE_OVERRIDE"
else
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
fi

log_info "Restoring OpenClaw configuration from backup..."

# Restore each config section
if [[ -f "$SCRIPT_DIR/agents.json" ]]; then
  log_info "Restoring agents configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set agents "$(cat "$SCRIPT_DIR/agents.json")" 2>/dev/null || {
    log_warn "Could not restore agents config"
  }
fi

if [[ -f "$SCRIPT_DIR/tools.json" ]]; then
  log_info "Restoring tools configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set tools "$(cat "$SCRIPT_DIR/tools.json")" 2>/dev/null || {
    log_warn "Could not restore tools config"
  }
fi

if [[ -f "$SCRIPT_DIR/skills.json" ]]; then
  log_info "Restoring skills configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set skills "$(cat "$SCRIPT_DIR/skills.json")" 2>/dev/null || {
    log_warn "Could not restore skills config"
  }
fi

if [[ -f "$SCRIPT_DIR/models.json" ]]; then
  log_info "Restoring models configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set models "$(cat "$SCRIPT_DIR/models.json")" 2>/dev/null || {
    log_warn "Could not restore models config"
  }
fi

if [[ -f "$SCRIPT_DIR/auth.json" ]]; then
  log_info "Restoring auth configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set auth "$(cat "$SCRIPT_DIR/auth.json")" 2>/dev/null || {
    log_warn "Could not restore auth config"
  }
fi

if [[ -f "$SCRIPT_DIR/queue.json" ]]; then
  log_info "Restoring queue configuration..."
  $COMPOSE_CMD run --rm \
    -e OPENCLAW_CONFIG_DIR=/home/node/.openclaw \
    openclaw-cli config set messages.queue "$(cat "$SCRIPT_DIR/queue.json")" 2>/dev/null || {
    log_warn "Could not restore queue config"
  }
fi

# Restore exec-approvals.json
if [[ -f "$SCRIPT_DIR/exec-approvals.json" ]]; then
  log_info "Restoring exec-approvals.json..."
  docker compose cp "$SCRIPT_DIR/exec-approvals.json" openclaw-gateway:/home/node/.openclaw/exec-approvals.json 2>/dev/null || {
    log_warn "Could not restore exec-approvals.json"
  }
fi

# Restore custom skills
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  log_info "Restoring custom skills..."
  for skill_dir in "$SCRIPT_DIR/skills"/*; do
    if [[ -d "$skill_dir" ]]; then
      skill_name=$(basename "$skill_dir")
      log_info "Restoring skill: $skill_name"
      docker compose cp "$skill_dir" openclaw-gateway:/app/skills/ 2>/dev/null || {
        log_warn "Could not restore skill: $skill_name"
      }
    fi
  done
fi

log_success "Configuration restore completed!"
log_info "Restart the gateway to apply: docker compose restart openclaw-gateway"
RESTORESCRIPT

chmod +x "$BACKUP_DIR/restore.sh"

# Create a summary file
cat > "$BACKUP_DIR/README.md" << READMEEOF
# OpenClaw Configuration Backup

Created: $(date)

## Contents

- \`openclaw.json\` - Full configuration export
- \`agents.json\` - Agent defaults and settings
- \`tools.json\` - Tool configuration (exec, web_search, etc.)
- \`skills.json\` - Enabled skills (trello, brave, etc.)
- \`models.json\` - Model settings
- \`auth.json\` - Authentication profiles
- \`queue.json\` - Rate limiting and queue settings
- \`exec-approvals.json\` - Exec tool approvals
- \`skills/\` - Custom skill definitions

## Usage

### To restore on another machine:

1. Copy this backup directory to the new machine
2. Run the restore script:
   \`\`\`bash
   ./restore.sh
   \`\`\`
3. Restart the gateway:
   \`\`\`bash
   docker compose restart openclaw-gateway
   \`\`\`

### Important Notes

- API keys are NOT backed up (they should be in .env)
- Session history is NOT backed up
- Only configuration and skills are preserved
READMEEOF

log_success "Backup completed!"
log_info "Backup location: $BACKUP_DIR"
log_info "Files backed up:"
ls -la "$BACKUP_DIR/"

log_info ""
log_info "To restore on another machine:"
log_info "  1. Copy $BACKUP_DIR to the new machine"
log_info "  2. Run: ./$BACKUP_DIR/restore.sh"
log_info "  3. Restart: docker compose restart openclaw-gateway"
