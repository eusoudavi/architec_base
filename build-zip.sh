#!/usr/bin/env bash
# Gera dist/<skill>.zip para upload no claude.ai (Settings → Capabilities → Skills).
# Se a skill tiver .claudeai-description, ela substitui a descrição no zip
# (o upload do claude.ai pode limitar a descrição a 200 caracteres).
# Uso: ./build-zip.sh            # todas as skills
#      ./build-zip.sh arquiteto-base
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
OUT="$REPO/dist"; mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

skills=("$@")
if [ ${#skills[@]} -eq 0 ]; then
  for d in "$REPO"/*/; do [ -f "$d/SKILL.md" ] && skills+=("$(basename "$d")"); done
fi

for name in "${skills[@]}"; do
  src="$REPO/$name"
  [ -f "$src/SKILL.md" ] || { echo "skill não encontrada: $name" >&2; exit 1; }
  cp -R "$src" "$TMP/$name"
  if [ -f "$src/.claudeai-description" ]; then
    desc="$(tr -d '\n' < "$src/.claudeai-description")"
    DESC="$desc" perl -0pi -e 's/^description: .*$/description: $ENV{DESC}/m' "$TMP/$name/SKILL.md"
  fi
  len=$(awk '/^description:/{sub(/^description: /,""); print length($0); exit}' "$TMP/$name/SKILL.md")
  [ "$len" -le 200 ] || echo "aviso: descrição de $name tem $len caracteres (>200)" >&2
  rm -f "$OUT/$name.zip"
  (cd "$TMP" && zip -qrX "$OUT/$name.zip" "$name" -x '*/.*')
  echo "ok  dist/$name.zip"
done
