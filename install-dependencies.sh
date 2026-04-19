#!/bin/bash

# TOON Global Setup - Install Dependencies
# Installs TOON libraries across all AI tool ecosystems

set -e

TOON_VERSION="latest"
TOON_SETUP_DIR="$HOME/.claude/toon-setup"

echo "🔧 Installing TOON format dependencies globally..."

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Node.js/NPM (for Claude CLI, Gemini CLI, general tooling)
if command -v npm &> /dev/null; then
    echo -e "${BLUE}→ Installing @toon/format (Node.js)...${NC}"
    npm install -g @toon/format 2>/dev/null || npm install -g toon-format 2>/dev/null || echo -e "${YELLOW}⚠ TOON npm package not found in global registry${NC}"
    echo -e "${GREEN}✓ Node.js TOON support installed${NC}"
fi

# 2. Python (for Gemini SDK, general AI tools)
if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
    echo -e "${BLUE}→ Installing toon-format (Python)...${NC}"
    pip3 install --user toon-format 2>/dev/null || pip install --user toon-format 2>/dev/null || echo -e "${YELLOW}⚠ TOON Python package not found${NC}"
    echo -e "${GREEN}✓ Python TOON support installed${NC}"
fi

# 3. Go (for container/cloud tooling)
if command -v go &> /dev/null; then
    echo -e "${BLUE}→ Installing TOON Go library...${NC}"
    go install github.com/toon-format/toon/go@latest 2>/dev/null || echo -e "${YELLOW}⚠ TOON Go package not found${NC}"
    echo -e "${GREEN}✓ Go TOON support installed${NC}"
fi

# 4. Rust (for RTK integration)
if command -v cargo &> /dev/null; then
    echo -e "${BLUE}→ Installing TOON Rust crate...${NC}"
    cargo install toon-format 2>/dev/null || echo -e "${YELLOW}⚠ TOON Rust crate not found${NC}"
    echo -e "${GREEN}✓ Rust TOON support installed${NC}"
fi

# 5. Create local TOON converter utility (Node.js - primary)
if command -v node &> /dev/null; then
    echo -e "${BLUE}→ Creating TOON converter utility...${NC}"
    cat > "$TOON_SETUP_DIR/converter.js" << 'EOF'
#!/usr/bin/env node

/**
 * TOON Format Converter - Converts between JSON, TOON, and Markdown
 * Usage: converter.js <command> [input] [options]
 * Commands: json-to-toon, toon-to-json, md-to-toon, toon-to-md
 */

const fs = require('fs');
const path = require('path');

class TOONConverter {
  /**
   * Convert JSON to TOON format
   * @param {Object} data - JSON data to convert
   * @returns {string} TOON formatted string
   */
  static jsonToToon(data) {
    if (Array.isArray(data)) {
      return this.arrayToToon(data);
    } else if (typeof data === 'object' && data !== null) {
      return this.objectToToon(data);
    }
    return String(data);
  }

  /**
   * Convert array to TOON tabular format
   * Detects uniform arrays and uses compact tabular format
   */
  static arrayToToon(arr) {
    if (arr.length === 0) return 'items[0]:';

    const firstItem = arr[0];
    const isUniform = arr.every(item =>
      typeof item === 'object' &&
      item !== null &&
      Object.keys(item).length === Object.keys(firstItem).length &&
      Object.keys(item).every(k => k in firstItem)
    );

    if (isUniform && typeof firstItem === 'object') {
      // Uniform array - use tabular format
      const keys = Object.keys(firstItem);
      const rows = arr.map(item =>
        keys.map(k => this.escapeValue(item[k])).join(',')
      );
      const header = `items[${arr.length}]{${keys.join(',')}}:`;
      return header + '\n  ' + rows.join('\n  ');
    } else {
      // Non-uniform array - line by line
      return arr.map((item, i) => {
        if (typeof item === 'object' && item !== null) {
          return `[${i}]:\n` + this.objectToToon(item).split('\n').map(l => '  ' + l).join('\n');
        }
        return `[${i}]: ${this.escapeValue(item)}`;
      }).join('\n');
    }
  }

  static objectToToon(obj, indent = 0) {
    const prefix = ' '.repeat(indent);
    const lines = [];

    for (const [key, value] of Object.entries(obj)) {
      if (Array.isArray(value)) {
        lines.push(`${prefix}${key}:`);
        lines.push(this.arrayToToon(value).split('\n').map(l => '  ' + l).join('\n'));
      } else if (typeof value === 'object' && value !== null) {
        lines.push(`${prefix}${key}:`);
        lines.push(this.objectToToon(value, indent + 2));
      } else {
        lines.push(`${prefix}${key}: ${this.escapeValue(value)}`);
      }
    }
    return lines.join('\n');
  }

  static escapeValue(val) {
    if (val === null) return 'null';
    if (typeof val === 'boolean') return val ? 'true' : 'false';
    if (typeof val === 'number') return String(val);
    if (typeof val === 'string') {
      if (/[,\n"]/.test(val)) return `"${val.replace(/"/g, '\\"')}"`;
      return val;
    }
    return String(val);
  }

  /**
   * Parse TOON format back to JSON
   */
  static toonToJson(toonStr) {
    // Simplified TOON parser
    const lines = toonStr.split('\n');
    return this.parseLines(lines, 0).result;
  }

  static parseLines(lines, startIdx, parentIndent = 0) {
    const obj = {};
    let i = startIdx;

    while (i < lines.length) {
      const line = lines[i];
      if (!line.trim()) { i++; continue; }

      const indent = line.match(/^(\s*)/)[1].length;
      if (indent < parentIndent) break;
      if (indent > parentIndent) { i++; continue; }

      if (line.includes('{') && line.includes('}')) {
        // Array declaration
        const match = line.match(/(\w+)\[(\d+)\]\{([^}]+)\}:/);
        if (match) {
          const [, name, length, fields] = match;
          const fieldList = fields.split(',');
          i++;
          const rows = [];
          for (let j = 0; j < parseInt(length); j++) {
            if (i >= lines.length) break;
            const rowLine = lines[i].trim();
            const values = rowLine.split(',');
            const row = {};
            fieldList.forEach((field, idx) => {
              row[field] = this.parseValue(values[idx]);
            });
            rows.push(row);
            i++;
          }
          obj[name] = rows;
          continue;
        }
      }

      const colonIdx = line.indexOf(':');
      if (colonIdx > -1) {
        const key = line.substring(indent, colonIdx).trim();
        const value = line.substring(colonIdx + 1).trim();
        if (value) {
          obj[key] = this.parseValue(value);
        } else {
          // Nested object or array
          i++;
          const nested = this.parseLines(lines, i, parentIndent + 2);
          obj[key] = nested.result;
          i = nested.nextIdx;
          continue;
        }
      }
      i++;
    }

    return { result: obj, nextIdx: i };
  }

  static parseValue(val) {
    if (val === 'null') return null;
    if (val === 'true') return true;
    if (val === 'false') return false;
    if (!isNaN(val) && val !== '') return Number(val);
    if (val.startsWith('"') && val.endsWith('"')) {
      return val.slice(1, -1).replace(/\\"/g, '"');
    }
    return val;
  }
}

// CLI Interface
async function main() {
  const [command, inputPath, ...options] = process.argv.slice(2);

  if (!command || command === '--help' || command === '-h') {
    console.log(`
TOON Format Converter v1.0
Usage: converter.js <command> [input-file] [options]

Commands:
  json-to-toon <file>       Convert JSON file to TOON format
  toon-to-json <file>       Convert TOON file to JSON format
  md-to-toon <file>         Extract JSON from markdown and convert to TOON
  inline <json-string>      Convert inline JSON to TOON

Options:
  --output, -o <path>       Output file path (default: stdout)
  --compact                  Ultra-compact output
  --pretty                   Pretty-print output
    `);
    process.exit(0);
  }

  try {
    let result;
    const isInline = command === 'inline';
    const input = isInline ? inputPath : fs.readFileSync(inputPath, 'utf-8');

    switch (command) {
      case 'json-to-toon':
        const jsonData = JSON.parse(input);
        result = TOONConverter.jsonToToon(jsonData);
        break;
      case 'toon-to-json':
        result = JSON.stringify(TOONConverter.toonToJson(input), null, 2);
        break;
      case 'md-to-toon': {
        // Case 1: JSON code block
        const jsonMatch = input.match(/\`\`\`json\n([\s\S]*?)\n\`\`\`/);
        if (jsonMatch) {
          result = TOONConverter.jsonToToon(JSON.parse(jsonMatch[1]));
          break;
        }
        // Case 2: YAML frontmatter (--- blocks)
        const fmMatch = input.match(/^---\n([\s\S]*?)\n---/);
        if (fmMatch) {
          const fmLines = fmMatch[1].split('\n');
          const obj = {};
          fmLines.forEach(line => {
            const idx = line.indexOf(':');
            if (idx > -1) {
              const k = line.slice(0, idx).trim();
              const v = line.slice(idx + 1).trim();
              if (k && v) obj[k] = v;
            }
          });
          // Append body content as 'content' field
          const body = input.slice(fmMatch[0].length).trim();
          if (body) obj.content = body.replace(/\n/g, ' ').slice(0, 500);
          result = TOONConverter.jsonToToon(obj);
          break;
        }
        // Case 3: Plain markdown — treat as content string
        result = 'content: ' + input.replace(/\n/g, ' ').slice(0, 500);
        break;
      }
      case 'inline':
        const inlineJson = JSON.parse(input);
        result = TOONConverter.jsonToToon(inlineJson);
        break;
      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }

    const outputPath = options.includes('-o') ? options[options.indexOf('-o') + 1] :
                       options.includes('--output') ? options[options.indexOf('--output') + 1] : null;

    if (outputPath) {
      fs.writeFileSync(outputPath, result);
      console.log(`✓ Written to ${outputPath}`);
    } else {
      console.log(result);
    }
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { TOONConverter };
EOF
    chmod +x "$TOON_SETUP_DIR/converter.js"
    echo -e "${GREEN}✓ TOON converter utility created${NC}"
fi

echo -e "\n${GREEN}✓ All TOON dependencies installed successfully!${NC}"
echo -e "${YELLOW}Next: Run 'toon-setup-config' to configure AI tools${NC}"
