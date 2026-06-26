#!/usr/bin/env bash
#
# build.sh — Build IntentCraft.app and package it into a distributable .dmg.
#
# Usage:
#   ./build.sh            # build .app and .dmg into ./dist
#   ./build.sh --app      # build only IntentCraft.app
#   ./build.sh --cli      # build & install the `intentcraft` CLI to /usr/local/bin
#   ./build.sh --clean    # remove build + dist artifacts
#
# Requirements: macOS 26+ and Xcode 26+ (the FoundationModels macro plugin ships
# with Xcode, not the bare Command Line Tools).

set -euo pipefail

# ---- configuration ---------------------------------------------------------
APP_NAME="IntentCraft"
PRODUCT="IntentCraftApp"          # SPM executable product
CLI_PRODUCT="intentcraft"
BUNDLE_ID="com.intentcraft.app"
VERSION="0.1.0"
MIN_MACOS="26.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
APP_BUNDLE="$DIST/$APP_NAME.app"
DMG_PATH="$DIST/$APP_NAME-$VERSION.dmg"

# ---- pick a toolchain that has the FoundationModels macro plugin -----------
# Prefer a full Xcode install; fall back to whatever is active.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

info()  { printf '\033[36m●\033[0m %s\n' "$1"; }
ok()    { printf '\033[32m✓\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m!\033[0m %s\n' "$1"; }

require_xcode() {
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    warn "No usable Swift toolchain found."
    exit 1
  fi
  if [[ "${DEVELOPER_DIR:-}" != *"Xcode.app"* ]]; then
    warn "DEVELOPER_DIR is not pointing at Xcode.app."
    warn "FoundationModels macros (@Generable/@Guide) need the Xcode toolchain."
    warn "Install Xcode 26+ and re-run, or: export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
  fi
}

clean() {
  info "Cleaning build artifacts…"
  rm -rf "$ROOT/.build" "$DIST"
  ok "Clean."
}

build_release() {
  require_xcode
  info "Building $PRODUCT (release)…"
  ( cd "$ROOT" && swift build -c release --product "$PRODUCT" )
  ok "Built release binary."
}

make_app() {
  build_release
  local bin
  bin="$(cd "$ROOT" && swift build -c release --product "$PRODUCT" --show-bin-path)/$PRODUCT"

  info "Assembling $APP_NAME.app…"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

  cp "$bin" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

  cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key><string>MIT License · IntentCraft contributors</string>
</dict>
</plist>
PLIST

  echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

  # Ad-hoc sign so Gatekeeper lets local users run it. Replace "-" with your
  # Developer ID identity to produce a notarizable build.
  info "Ad-hoc code signing…"
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || \
    warn "codesign failed (app still runnable locally via right-click ▸ Open)."

  ok "Created $APP_BUNDLE"
}

make_dmg() {
  make_app
  command -v hdiutil >/dev/null 2>&1 || { warn "hdiutil not found."; exit 1; }

  info "Packaging .dmg…"
  rm -f "$DMG_PATH"
  local staging
  staging="$(mktemp -d)"
  cp -R "$APP_BUNDLE" "$staging/"
  ln -s /Applications "$staging/Applications"   # drag-to-install affordance

  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$staging" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

  rm -rf "$staging"
  ok "Created $DMG_PATH"
}

install_cli() {
  require_xcode
  info "Building & installing CLI ($CLI_PRODUCT)…"
  ( cd "$ROOT" && swift build -c release --product "$CLI_PRODUCT" )
  local bin
  bin="$(cd "$ROOT" && swift build -c release --product "$CLI_PRODUCT" --show-bin-path)/$CLI_PRODUCT"
  local dest="/usr/local/bin/$CLI_PRODUCT"
  if [[ -w "$(dirname "$dest")" ]]; then
    cp "$bin" "$dest"
  else
    sudo cp "$bin" "$dest"
  fi
  ok "Installed $dest"
}

main() {
  mkdir -p "$DIST"
  case "${1:-}" in
    --clean) clean ;;
    --app)   make_app ;;
    --cli)   install_cli ;;
    --dmg|"") make_dmg ;;
    *) warn "Unknown option: $1"; exit 1 ;;
  esac
  if [[ "${1:-}" == "" || "${1:-}" == "--dmg" ]]; then
    echo
    ok "Done. Distributable disk image:"
    echo "    $DMG_PATH"
  fi
}

main "$@"
