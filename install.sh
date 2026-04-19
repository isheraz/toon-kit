#!/bin/bash

# TOON Global Setup - Universal Installer
# Installs TOON (Token-Oriented Object Notation) global context setup
# Works from any directory - automatically handles paths

set -e

# Detect installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOON_SETUP_DIR="${HOME}/.claude/toon-setup"
TOON_CONTEXT_DIR="${HOME}/.claude/toon-context"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# Main Installation
# ============================================================================

main() {
  local action="${1:-install}"

  case "$action" in
    install|setup|--silent)
      full_install "$action"
      ;;
    verify)
      verify_install
      ;;
    uninstall)
      uninstall_setup
      ;;
    *)
      show_help
      ;;
  esac
}

# ============================================================================
# Full Installation
# ============================================================================

full_install() {
  # Detect silent mode (npm postinstall or explicit --silent flag)
  local silent=false
  [[ "${npm_lifecycle_event}" == "postinstall" || "$1" == "--silent" ]] && silent=true

  if [ "$silent" = false ]; then
    echo -e "\n${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ TOON Global Setup - Installation               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
    echo "Installation source: $INSTALL_DIR"
    echo "Installation target: $TOON_SETUP_DIR"
    echo ""
  fi

  # Create target directories
  mkdir -p "$TOON_SETUP_DIR" "$TOON_CONTEXT_DIR"

  # Copy all files
  cp "$INSTALL_DIR"/*.sh "$TOON_SETUP_DIR/" 2>/dev/null || true
  cp "$INSTALL_DIR"/*.js "$TOON_SETUP_DIR/" 2>/dev/null || true
  cp "$INSTALL_DIR"/*.md "$TOON_SETUP_DIR/" 2>/dev/null || true
  cp "$INSTALL_DIR/ton"  "$TOON_SETUP_DIR/ton" 2>/dev/null || true
  chmod +x "$TOON_SETUP_DIR"/*.sh "$TOON_SETUP_DIR/ton" 2>/dev/null || true
  [ "$silent" = false ] && echo -e "${GREEN}✓ Files copied${NC}"

  # Copy skill file for Claude Code
  mkdir -p "$HOME/.claude/skills"
  cp "$INSTALL_DIR/skill.md" "$HOME/.claude/skills/ton.md" 2>/dev/null || true
  [ "$silent" = false ] && echo -e "${GREEN}✓ Skill installed${NC}"

  # Configure Claude settings (Stop hook + contextStorage) silently
  configure_claude_settings
  [ "$silent" = false ] && echo -e "${GREEN}✓ Claude configured${NC}"

  # Shell integration
  setup_shell_integration "$silent"

  # Register launchd auto-start (macOS)
  register_launchd "$silent"

  if [ "$silent" = true ]; then
    echo "tonpack: installed and configured. Reload your shell: exec zsh"
  else
    echo -e "\n${GREEN}✓ Installation complete!${NC}\n"
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Reload shell:  exec zsh"
    echo "  2. Check status:  ton verify"
    echo "  3. View savings:  ton stats"
    echo ""
    echo -e "${YELLOW}Quick reference:${NC}"
    echo "  ton help    - Show all commands"
    echo "  ton stats   - Show token savings"
    echo "  ton convert - Convert memory to TOON"
    echo ""
  fi
}

# ============================================================================
# Configure Claude settings.json silently
# ============================================================================

configure_claude_settings() {
  local settings="$HOME/.claude/settings.json"
  [ ! -f "$settings" ] && return 0

  # Skip if Stop hook already present
  grep -q "save-context-toon" "$settings" && return 0

  # Use node to safely merge JSON (available since we require node >=14)
  node - "$settings" "$TOON_SETUP_DIR" << 'JSEOF'
const fs = require('fs');
const path = process.argv[2];
const toonDir = process.argv[3];
try {
  const s = JSON.parse(fs.readFileSync(path, 'utf8'));
  if (!s.hooks) s.hooks = {};
  if (!s.hooks.Stop) s.hooks.Stop = [];
  const hook = { hooks: [{ type: 'command', command: toonDir + '/hooks/save-context-toon.sh' }] };
  s.hooks.Stop.push(hook);
  if (!s.contextStorage) s.contextStorage = { format: 'toon', path: process.env.HOME + '/.claude/toon-context', autoCompress: true, compressThreshold: 50000 };
  fs.writeFileSync(path, JSON.stringify(s, null, 2));
} catch(e) {}
JSEOF

  # Ensure hooks directory and script exist
  mkdir -p "$TOON_SETUP_DIR/hooks"
  if [ ! -f "$TOON_SETUP_DIR/hooks/save-context-toon.sh" ]; then
    cat > "$TOON_SETUP_DIR/hooks/save-context-toon.sh" << 'HOOKEOF'
#!/bin/bash
# TOON: Auto-convert memory files after each Claude Code session
"$HOME/.claude/toon-setup/memory-converter.sh" convert "$PWD" 2>/dev/null || true
HOOKEOF
    chmod +x "$TOON_SETUP_DIR/hooks/save-context-toon.sh"
  fi
}

# ============================================================================
# Shell Integration
# ============================================================================

setup_shell_integration() {
  local silent="${1:-false}"
  local shell_rc=""

  if [ -f "$HOME/.zshrc" ]; then
    shell_rc="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  else
    [ "$silent" = false ] && echo -e "${YELLOW}⚠ No shell RC file found. Skipping shell integration.${NC}"
    return 0
  fi

  if grep -q "toon-setup/shell-integration.sh" "$shell_rc"; then
    [ "$silent" = false ] && echo -e "${GREEN}✓ Already integrated in $shell_rc${NC}"
    return 0
  fi

  cat >> "$shell_rc" << 'RCEOF'

# tonpack — TOON token optimizer (https://github.com/isheraz/tonpack)
source "$HOME/.claude/toon-setup/shell-integration.sh" 2>/dev/null || true
RCEOF

  [ "$silent" = false ] && echo -e "${GREEN}✓ Integrated into $shell_rc${NC}"
}

# ============================================================================
# Register launchd for auto-start (macOS)
# ============================================================================

register_launchd() {
  local silent="${1:-false}"
  local plist="$HOME/Library/LaunchAgents/com.tonpack.serve.plist"
  local node_path

  # Find node binary
  node_path=$(which node 2>/dev/null) || {
    [ "$silent" = false ] && echo -e "${YELLOW}⚠ node not found — skipping auto-start${NC}"
    return 0
  }

  # Write launchd plist
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.tonpack.serve</string>
  <key>ProgramArguments</key>
  <array>
    <string>${node_path}</string>
    <string>${TOON_SETUP_DIR}/toon-serve.js</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/ton-serve.log</string>
  <key>StandardErrorPath</key><string>/tmp/ton-serve.err</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>${HOME}</string>
    <key>TOON_SERVE_PORT</key><string>7878</string>
  </dict>
</dict>
</plist>
PLIST

  # Load plist
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load "$plist" 2>/dev/null && {
    [ "$silent" = false ] && echo -e "${GREEN}✓ Auto-start registered (launchd)${NC}"
  } || {
    [ "$silent" = false ] && echo -e "${YELLOW}⚠ launchctl failed — fallback to shell startup${NC}"
  }
}

# ============================================================================
# Verify Installation
# ============================================================================

verify_install() {
  echo -e "\n${BLUE}Verifying TOON installation...${NC}\n"

  if [ ! -d "$TOON_SETUP_DIR" ]; then
    echo -e "${RED}✗ Setup directory not found: $TOON_SETUP_DIR${NC}"
    echo -e "${YELLOW}Run: bash $INSTALL_DIR/install.sh${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ Setup directory: $TOON_SETUP_DIR${NC}"
  echo -e "${GREEN}✓ Context directory: $TOON_CONTEXT_DIR${NC}"

  # Check components
  local missing=0
  for component in install-dependencies.sh configure-ai-tools.sh toon-utils.sh shell-integration.sh ton; do
    if [ -f "$TOON_SETUP_DIR/$component" ]; then
      echo -e "${GREEN}✓ $component${NC}"
    else
      echo -e "${RED}✗ $component${NC}"
      missing=$((missing + 1))
    fi
  done

  if [ $missing -eq 0 ]; then
    echo -e "\n${GREEN}✓ Installation verified successfully!${NC}"
    echo -e "${BLUE}Run: toon-setup${NC}"
    return 0
  else
    echo -e "\n${RED}✗ Some components missing. Reinstall: bash $INSTALL_DIR/install.sh${NC}"
    return 1
  fi
}

# ============================================================================
# Uninstall
# ============================================================================

uninstall_setup() {
  echo -e "${YELLOW}⚠ This will remove TOON setup${NC}"
  read -p "Are you sure? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TOON_SETUP_DIR"
    rm -f "$HOME/.claude/skills/toon-global-setup.sh"
    echo -e "${GREEN}✓ TOON setup removed${NC}"
  else
    echo "Uninstall cancelled."
  fi
}

# ============================================================================
# Help
# ============================================================================

show_help() {
  cat << 'EOF'

TOON Global Setup - Installer

USAGE:
  bash install.sh [command]

COMMANDS:
  install     Install TOON globally (default)
  verify      Verify installation
  uninstall   Remove TOON setup

EXAMPLES:
  bash install.sh              # Full installation
  bash install.sh verify       # Check installation
  bash install.sh uninstall    # Remove TOON

AFTER INSTALLATION:
  ton setup    # Run full setup
  ton verify   # Check status
  ton stats    # Show token savings

For more info: https://github.com/toon-format/toon

EOF
  exit 0
}

# ============================================================================
# Run
# ============================================================================

main "$@"
