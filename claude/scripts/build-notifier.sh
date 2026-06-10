#!/usr/bin/env bash
set -euo pipefail

# Builds ClaudeNotifier.app into the Claude config dir from
# claude/notifier/main.swift. The app posts clickable macOS notifications
# with the Claude icon; clicking one activates the app recorded by the
# notify hook. Requires swiftc from the Xcode Command Line Tools.
# CCNOTIFY_SKIP_BUILD=1 skips the build (the test suite sets it).

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
app="$claude_dir/ClaudeNotifier.app"
src="$module_dir/notifier/main.swift"
binary="$app/Contents/MacOS/ClaudeNotifier"

if [[ "${CCNOTIFY_SKIP_BUILD:-}" == "1" ]]; then
  exit 0
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Note: swiftc not found (install it with: xcode-select --install)."
  echo "Skipped building ClaudeNotifier; notifications fall back to osascript."
  exit 0
fi

if [[ -x "$binary" && "$binary" -nt "$src" && "$binary" -nt "${BASH_SOURCE[0]}" ]]; then
  echo "ClaudeNotifier is up to date."
  exit 0
fi

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$module_dir/assets/ccnotify.icns" "$app/Contents/Resources/ccnotify.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>ClaudeNotifier</string>
  <key>CFBundleIdentifier</key><string>io.github.co-index.dotfiles.ccnotify</string>
  <key>CFBundleName</key><string>ccnotify</string>
  <key>CFBundleDisplayName</key><string>ccnotify</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>ccnotify</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict>
</plist>
PLIST

echo "Compiling ClaudeNotifier (first build takes a few seconds) ..."
swiftc -O -o "$binary" "$src"
codesign --force --sign - "$app"
echo "Built $app"
echo "The first notification asks for permission; allow 'ccnotify' under"
echo "System Settings -> Notifications if banners do not appear."
