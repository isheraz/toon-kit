---
name: tonpack
description: Token-Oriented Object Notation (TOON) CLI for compressing AI context storage. Use when the user asks about toon, token optimization, ton commands, or wants to reduce LLM context costs.
---

# tonpack — TOON Token Optimizer

`ton` is a CLI tool that compresses AI memory and context files from JSON/Markdown to TOON format, reducing token consumption by 30–90%.

## Installation

```bash
npm install -g tonpack
exec zsh          # reload shell to activate ton alias
ton setup         # configure Claude, Gemini, agy, Ollama
```

## Commands

```
ton setup               Install + configure all AI tools
ton verify              Check setup status
ton init [dir]          Create .toon/memory/ in a project (default: cwd)
ton convert [dir]       Convert memory files to TOON format
ton watch               Auto-convert on file change
ton stats               Show recorded token savings
ton clean [days]        Remove TOON files older than N days (default: 30)
ton export [fmt] [dir]  Export as json|toon|md
ton run <cmd> [args]    Direct converter: json-to-toon, toon-to-json, md-to-toon, inline
ton help                Show all commands
```

## How It Works

1. Memory files (`.md` containing JSON blocks) are converted to TOON format
2. TOON uses CSV-like tabular layout instead of verbose JSON
3. Converted files stored in `~/.claude/toon-context/`
4. Claude Code `Stop` hook auto-converts after each session

## Project-Local Memory

```bash
ton init                # creates .toon/memory/ in current project
ton convert .           # converts local + global memory
```

## Key Paths

- Installed to: `~/.claude/toon-setup/`
- Context store: `~/.claude/toon-context/`
- Savings log: `~/.claude/toon-context/savings.log`
- Shell alias: sourced via `~/.zshrc`
- Hook: `~/.claude/toon-setup/hooks/save-context-toon.sh` (Stop event)

## TOON Format Example

**Before (JSON):**
```json
{"users":[{"id":1,"name":"Alice","role":"admin"},{"id":2,"name":"Bob","role":"user"}]}
```

**After (TOON):**
```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

**Savings: ~50%**
</content>
