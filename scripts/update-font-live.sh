#!/bin/bash
# Live Font Size Updater
# Usage: ./scripts/update-font-live.sh body 18

set -e

STYLE=$1
SIZE=$2

if [ -z "$STYLE" ] || [ -z "$SIZE" ]; then
  echo "Usage: ./scripts/update-font-live.sh <style> <size>"
  echo ""
  echo "Styles: display, h1, h2, h3, body, bodySmall, caption"
  echo "Example: ./scripts/update-font-live.sh body 18"
  exit 1
fi

echo "🎨 Updating $STYLE to ${SIZE}px..."

# Update the JSON token
cd "$(dirname "$0")/.."
jq ".primitives.primitives.fontSizes.$STYLE.\"\$value\" = \"${SIZE}px\"" \
  lib/design/tokens/primitives.json > tmp.json && \
  mv tmp.json lib/design/tokens/primitives.json

# Rebuild tokens
echo "🔨 Rebuilding design tokens..."
node style-dictionary-build.mjs > /dev/null 2>&1

echo "✅ Done! $STYLE is now ${SIZE}px"
echo ""
echo "Reload your app to see changes"