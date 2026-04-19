#!/bin/bash

# TOON Shell Integration - Add to ~/.zshrc or ~/.bashrc
# This file provides global toon-* command aliases

TOON_SETUP_DIR="$HOME/.claude/toon-setup"
TOON_SKILLS_DIR="$HOME/.claude/skills"

# ============================================================================
# Global TOON Commands (aliases and functions)
# ============================================================================

alias ton='bash '"$TOON_SETUP_DIR"'/ton'

# ============================================================================
# Export for shell initialization
# ============================================================================

# This script should be sourced in ~/.zshrc or ~/.bashrc

export TOON_SETUP_DIR
export TOON_SKILLS_DIR
export PATH="$TOON_SETUP_DIR:$PATH"

# ============================================================================
# Lazy-start ton serve if not running (fallback for non-launchd systems)
# ============================================================================

_ton_ensure_serve() {
  # Check if server is already running
  curl -sf "http://127.0.0.1:${TOON_SERVE_PORT:-7878}/health" > /dev/null 2>&1 && return 0
  # Start server in background if not running
  nohup node "$TOON_SETUP_DIR/toon-serve.js" > /dev/null 2>&1 &
  disown
}

# Run silently on shell init
_ton_ensure_serve 2>/dev/null || true
