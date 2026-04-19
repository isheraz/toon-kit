#!/bin/bash

# TOON Global Setup - Configure AI Tools
# Configures Claude, Gemini, agy, and ollama to use TOON context storage

set -e

TOON_SETUP_DIR="$HOME/.claude/toon-setup"
TOON_CONTEXT_DIR="$HOME/.claude/toon-context"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$TOON_CONTEXT_DIR"

echo "🔧 Configuring AI tools for TOON context storage..."

# ============================================================================
# 1. CLAUDE CLI - Update settings.json to use TOON context serialization
# ============================================================================
echo -e "${BLUE}→ Configuring Claude CLI...${NC}"

CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Add TOON context hook if not present
if ! grep -q "toon-context" "$CLAUDE_SETTINGS"; then
  # Read current settings
  CURRENT_SETTINGS=$(cat "$CLAUDE_SETTINGS")

  # Create updated settings with TOON context serialization
  cat > "$CLAUDE_SETTINGS.tmp" << 'EOF'
{
  "model": "haiku",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/sheraz/.claude/hooks/rtk-rewrite.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/Users/sheraz/.claude/toon-setup/hooks/save-context-toon.sh"
          }
        ]
      }
    ]
  },
  "contextStorage": {
    "format": "toon",
    "path": "/Users/sheraz/.claude/toon-context",
    "autoCompress": true,
    "compressThreshold": 50000
  }
}
EOF
  mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
  echo -e "${GREEN}✓ Claude CLI configured for TOON context${NC}"
else
  echo -e "${YELLOW}✓ Claude already configured for TOON${NC}"
fi

# ============================================================================
# 2. GEMINI CLI - Configure environment and hooks
# ============================================================================
echo -e "${BLUE}→ Configuring Gemini CLI...${NC}"

GEMINI_CONFIG_DIR="$HOME/.config/gemini-cli"
mkdir -p "$GEMINI_CONFIG_DIR"

cat > "$GEMINI_CONFIG_DIR/toon-config.json" << 'EOF'
{
  "contextFormat": "toon",
  "contextPath": "/Users/sheraz/.claude/toon-context",
  "contextServerUrl": "http://localhost:7878/context",
  "contextServerHealth": "http://localhost:7878/health",
  "hooks": {
    "beforeToolUse": "rtk hook gemini",
    "afterContextSave": "toon-converter md-to-toon"
  },
  "serialization": {
    "format": "toon",
    "compression": "auto"
  }
}
EOF

echo -e "${GREEN}✓ Gemini CLI configured for TOON context${NC}"

# ============================================================================
# 3. agy (Antigravity) - Configure TOON context
# ============================================================================
echo -e "${BLUE}→ Configuring agy (Antigravity)...${NC}"

AGY_CONFIG_DIR="$HOME/.antigravity"
mkdir -p "$AGY_CONFIG_DIR"

cat > "$AGY_CONFIG_DIR/toon.toml" << 'EOF'
[context]
format = "toon"
path = "/Users/sheraz/.claude/toon-context"
server_url = "http://localhost:7878/context"
health_url = "http://localhost:7878/health"
auto_compress = true

[serialization]
strategy = "toon"
compress_threshold = 50000

[memory]
storage_format = "toon"
enable_auto_conversion = true
EOF

echo -e "${GREEN}✓ agy configured for TOON context${NC}"

# ============================================================================
# 4. Ollama - Configure TOON context through environment
# ============================================================================
echo -e "${BLUE}→ Configuring Ollama...${NC}"

OLLAMA_CONFIG_DIR="$HOME/.ollama"
mkdir -p "$OLLAMA_CONFIG_DIR"

cat > "$OLLAMA_CONFIG_DIR/toon-context.json" << 'EOF'
{
  "contextFormat": "toon",
  "contextStoragePath": "/Users/sheraz/.claude/toon-context",
  "contextServerUrl": "http://localhost:7878/context",
  "contextServerHealth": "http://localhost:7878/health",
  "serialization": {
    "encoder": "toon",
    "decoder": "toon-to-json"
  },
  "prompting": {
    "contextEncoding": "toon",
    "preserveStructure": true
  }
}
EOF

echo -e "${GREEN}✓ Ollama configured for TOON context${NC}"
echo -e "${YELLOW}Note:${NC} To inject TOON context into Ollama prompts, use:"
echo -e "  ${D}curl -s http://localhost:7878/context | jq -r 'to_entries[].value.content' | ollama run <model>${NC}"

# ============================================================================
# 5. Create Global Memory Conversion Service
# ============================================================================
echo -e "${BLUE}→ Setting up global memory conversion service...${NC}"

cat > "$TOON_SETUP_DIR/memory-converter.sh" << 'EOF'
#!/bin/bash

# TOON Memory Converter - Converts markdown memory to TOON format
# Scans ~/.claude/projects/*/memory/ and optional local .toon/memory/

TOON_CONTEXT_DIR="$HOME/.claude/toon-context"
CONVERTER="$HOME/.claude/toon-setup/converter.js"

G='\033[0;32m'; Y='\033[1;33m'; D='\033[2m'; NC='\033[0m'

_convert_file() {
  local md_file="$1" label="$2"
  local filename toon_file original_size toon_size
  filename=$(basename "$md_file" .md)
  toon_file="$TOON_CONTEXT_DIR/${label}__${filename}.toon"

  command -v node &> /dev/null && [ -f "$CONVERTER" ] || return 1
  original_size=$(wc -c < "$md_file" | tr -d ' ')
  node "$CONVERTER" md-to-toon "$md_file" -o "$toon_file" 2>>"$TOON_CONTEXT_DIR/errors.log" || {
    echo "$(date +%s)|ERROR|$md_file" >> "$TOON_CONTEXT_DIR/savings.log"
    return 0
  }
  toon_size=$(wc -c < "$toon_file" | tr -d ' ')
  echo "$(date +%s)|$original_size|$toon_size|${label}__${filename}" >> "$TOON_CONTEXT_DIR/savings.log"
  echo -e "  ${G}✓${NC} $filename.md ${D}→${NC} ${toon_size}B ${D}(saved $((original_size - toon_size))B)${NC}"
}

convert_memory_to_toon() {
  local project_dir="${1:-}"
  local found=0
  mkdir -p "$TOON_CONTEXT_DIR"

  # 1. Global: ~/.claude/projects/*/memory/
  for md_file in "$HOME/.claude/projects"/*/memory/*.md; do
    [ -f "$md_file" ] || continue
    found=1
    local project
    project=$(basename "$(dirname "$(dirname "$md_file")")")
    _convert_file "$md_file" "$project"
  done

  # 2. Local: <project_dir>/.toon/memory/ (created via ton init)
  if [ -n "$project_dir" ] && [ -d "$project_dir/.toon/memory" ]; then
    local label
    label=$(basename "$project_dir")
    for md_file in "$project_dir/.toon/memory"/*.md; do
      [ -f "$md_file" ] || continue
      found=1
      echo -e "\n  [local] $project_dir/.toon/memory/"
      _convert_file "$md_file" "local__$label"
    done
  fi

  if [ $found -eq 0 ]; then
    echo "No memory files found. Run 'ton init' to create a local memory dir."
  fi
  return 0
}

watch_and_convert() {
  if command -v fswatch &> /dev/null; then
    fswatch -r "$HOME/.claude/projects" | while read changed_file; do
      if [[ "$changed_file" == *.md ]]; then
        convert_memory_to_toon
      fi
    done
  else
    echo "⚠ fswatch not installed. Memory changes won't auto-convert."
    echo "  Install with: brew install fswatch"
  fi
}

case "${1:-convert}" in
  convert)
    convert_memory_to_toon "${2:-}"
    ;;
  watch)
    watch_and_convert
    ;;
  *)
    echo "Usage: $0 {convert|watch} [project-dir]"
    ;;
esac
EOF

chmod +x "$TOON_SETUP_DIR/memory-converter.sh"
echo -e "${GREEN}✓ Memory conversion service installed${NC}"

# ============================================================================
# 6. Create Hook for Session Context Saving
# ============================================================================
echo -e "${BLUE}→ Creating context save hook...${NC}"

mkdir -p "$HOME/.claude/toon-setup/hooks"

cat > "$HOME/.claude/toon-setup/hooks/save-context-toon.sh" << 'EOF'
#!/bin/bash

# Hook: Save context in TOON format when Claude Code session ends
# Called automatically by Claude Code via Stop hook

TOON_CONTEXT_DIR="$HOME/.claude/toon-context"
CONVERTER="$HOME/.claude/toon-setup/converter.js"

mkdir -p "$TOON_CONTEXT_DIR"

# Capture session context and serialize to TOON
if [ -n "$CLAUDE_SESSION_CONTEXT" ]; then
  TIMESTAMP=$(date +%s)
  SESSION_FILE="$TOON_CONTEXT_DIR/session-$TIMESTAMP.toon"

  echo "$CLAUDE_SESSION_CONTEXT" | \
    node "$CONVERTER" inline '@' -o "$SESSION_FILE" 2>/dev/null && \
    echo "Context saved to $SESSION_FILE"
fi

# Convert recent markdown memory files to TOON
"$HOME/.claude/toon-setup/memory-converter.sh" convert
EOF

chmod +x "$HOME/.claude/toon-setup/hooks/save-context-toon.sh"
echo -e "${GREEN}✓ Context save hook installed${NC}"

# ============================================================================
# Summary
# ============================================================================
echo -e "\n${GREEN}✓ All AI tools configured for TOON context storage!${NC}\n"

echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Claude CLI:   ~/.claude/settings.json (contextStorage.format = toon)"
echo "  Gemini CLI:   ~/.config/gemini-cli/toon-config.json"
echo "  agy:          ~/.antigravity/toon.toml"
echo "  Ollama:       ~/.ollama/toon-context.json"
echo "  Context Dir:  ~/.claude/toon-context/"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run: toon-memory-convert   (convert existing memory to TOON)"
echo "  2. Run: toon-verify           (verify all tools configured)"
echo "  3. Restart Claude Code to activate hooks"
echo ""
