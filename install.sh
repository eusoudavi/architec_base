#!/usr/bin/env bash
# Cria links em ~/.claude/skills para cada skill deste repositório.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$DEST"
for dir in "$REPO"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue
  target="$DEST/$name"
  if [ -L "$target" ]; then
    ln -sfn "${dir%/}" "$target"
  elif [ -e "$target" ]; then
    echo "pulando $name: $target já existe e não é link (mova ou apague antes)" >&2
    continue
  else
    ln -s "${dir%/}" "$target"
  fi
  echo "ok  $name -> $target"
done
