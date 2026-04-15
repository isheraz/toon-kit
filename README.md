# tonpack

> Compress AI context storage by 30–90% across Claude, Gemini, agy, and Ollama — automatically.

[![npm version](https://img.shields.io/npm/v/tonpack?color=cb3837&logo=npm)](https://www.npmjs.com/package/tonpack)
[![npm downloads](https://img.shields.io/npm/dm/tonpack?color=cb3837)](https://www.npmjs.com/package/tonpack)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-isheraz%2Ftonpack-181717?logo=github)](https://github.com/isheraz/tonpack)

**tonpack** installs the `ton` CLI and wires a silent hook into Claude Code that converts your AI memory files from verbose JSON/Markdown to [TOON format](https://github.com/toon-format/toon) — a compact, CSV-like notation designed for LLM input.

## Install

```bash
npm install -g tonpack
exec zsh               # reload shell to activate ton
```

> **npm:** [npmjs.com/package/tonpack](https://www.npmjs.com/package/tonpack)

That's it. The `postinstall` script silently:
- Copies files to `~/.claude/toon-setup/`
- Injects a `Stop` hook into `~/.claude/settings.json`
- Adds `ton` alias to your shell rc

From that point, every Claude Code session end triggers an automatic background conversion. No commands needed.

## TOON Format

**Before (JSON — ~450 tokens)**
```json
{
  "users": [
    {"id": 1, "name": "Alice", "role": "admin", "active": true},
    {"id": 2, "name": "Bob",   "role": "user",  "active": true},
    {"id": 3, "name": "Carol", "role": "user",  "active": false}
  ]
}
```

**After (TOON — ~180 tokens)**
```
users[3]{id,name,role,active}:
  1,Alice,admin,true
  2,Bob,user,true
  3,Carol,user,false
```

**60% fewer tokens. Lossless. Human-readable.**

## Commands

```
ton help                Show all commands
ton stats               Show recorded token savings
ton init [dir]          Create .toon/memory/ in a project (default: cwd)
ton convert [dir]       Convert memory files to TOON format
ton watch               Auto-convert on file change
ton verify              Check setup status
ton clean [days]        Remove TOON files older than N days (default: 30)
ton export [fmt] [dir]  Export context as json|toon|md
ton run <cmd> [args]    Direct converter access
```

### Converter

```bash
ton run json-to-toon data.json          # JSON file → TOON
ton run toon-to-json data.toon          # TOON file → JSON
ton run md-to-toon notes.md             # extract JSON block from .md → TOON
ton run inline '{"name":"Alice"}'       # inline JSON → TOON
```

## Project-Local Memory

Each project can have its own version-controllable memory:

```bash
cd my-project
ton init                # creates .toon/memory/
# add .md files with ```json blocks
ton convert .           # compress them to ~/.claude/toon-context/
```

Add `.toon/` to `.gitignore` if you don't want to commit memory files.

## How It Works

```
Claude Code session ends
        │
        ▼ (Stop hook fires silently)
~/.claude/toon-setup/hooks/save-context-toon.sh
        │
        ├── scans ~/.claude/projects/*/memory/*.md  (global)
        └── scans <cwd>/.toon/memory/*.md           (local)
                │
                ▼ (converter.js: md-to-toon)
        ~/.claude/toon-context/*.toon
                │
                ▼
        savings.log  →  ton stats
```

## Token Savings

```
$ ton stats
TON Token Savings
════════════════════════════════════════════════════════════
Total files:    12
Original size:  48K
TOON size:      18K
Bytes saved:    30K (62.5%)
Efficiency:     ████████████████░░░░░░░░░ 62.5%

By File
───────────────────────────────────────────────────────────────────────
  #    File                                 Original      TOON    Saved       %
───────────────────────────────────────────────────────────────────────
  1.  project_context                          12K         4K      8K    66.7%
  2.  user_profile                              8K         3K      5K    62.5%
  ...
```

## Claude Code Skill

Drop `skill.md` into `~/.claude/skills/ton.md` — Claude will automatically understand the tool and suggest `ton` commands in relevant conversations.

```bash
cp node_modules/tonpack/skill.md ~/.claude/skills/ton.md
```

This is done automatically by `npm install -g tonpack`.

## Integration with RTK

Combine with [RTK](https://github.com/sherazahmed93/rtk) for compressing command output:

| Layer | What it compresses | Savings |
|-------|--------------------|---------|
| RTK   | Shell command output (git, ls, etc.) | 60–90% |
| TOON  | AI memory and context storage | 30–90% |
| Both  | Everything | **80–95%** |

## Files

```
~/.claude/toon-setup/
├── ton                        # CLI entry point
├── toon-utils.sh              # verify, stats, init, cleanup, export
├── memory-converter.sh        # scans and converts .md memory files
├── configure-ai-tools.sh      # configures Claude/Gemini/agy/Ollama
├── install.sh                 # copies files + wires settings.json
├── shell-integration.sh       # ton alias
├── converter.js               # JSON ↔ TOON converter (Node.js)
└── hooks/
    └── save-context-toon.sh   # Stop hook: runs after each session

~/.claude/toon-context/
├── *.toon                     # compressed memory files
└── savings.log                # conversion history for ton stats
```

## Uninstall

```bash
rm -rf ~/.claude/toon-setup
# remove the source line from ~/.zshrc manually
```

## License

MIT © 2026 [Sheraz Ahmed](https://github.com/isheraz)
</content>
