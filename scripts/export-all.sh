#!/usr/bin/env bash
# Build final exports for all SyncBridge clients.
#
# Outputs:
#   releases/android/SyncBridge-release.apk
#   releases/android/SyncBridge-debug.apk
#   releases/macos/SyncBridge-Release.dmg
#   releases/ios/SyncBridge-Release.ipa
#   releases/web/                  (static site)
#   releases/SyncBridge-web.tar.gz
#   releases/backend/syncbridge-api-linux-amd64
#   releases/MANIFEST.txt
#
# Usage:
#   ./scripts/export-all.sh              # all platforms
#   ./scripts/export-all.sh web android  # subset
#   ./scripts/export-all.sh backend      # VPS binary only
#   VITE_API_URL=https://api.example.com ./scripts/export-all.sh web
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES="$ROOT/releases"
MANIFEST="$RELEASES/MANIFEST.txt"
VERSION="$(date -u +%Y%m%d-%H%M%S)"
GIT_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(web android macos ios backend)
fi

want() {
  local t="$1"
  for x in "${TARGETS[@]}"; do
    [[ "$x" == "$t" ]] && return 0
  done
  return 1
}

mkdir -p "$RELEASES"
: > "$MANIFEST.tmp"

log_manifest() {
  echo "$1" >> "$MANIFEST.tmp"
}

sha256_file() {
  if command -v shasum >/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "n/a"
  fi
}

record_artifact() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    local size hash
    size="$(du -h "$path" | awk '{print $1}')"
    hash="$(sha256_file "$path")"
    log_manifest "$label | $path | $size | sha256:$hash"
    echo "  ✓ $label ($size)"
  elif [[ -d "$path" ]]; then
    local size
    size="$(du -sh "$path" | awk '{print $1}')"
    log_manifest "$label | $path/ | $size | dir"
    echo "  ✓ $label ($size)"
  else
    log_manifest "$label | MISSING | - | -"
    echo "  ✗ $label (missing)"
  fi
}

FAILURES=()

run_target() {
  local name="$1"
  local script="$2"
  shift 2
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Building: $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "$script" "$@"; then
    echo "  Done: $name"
  else
    echo "  FAILED: $name" >&2
    FAILURES+=("$name")
  fi
}

echo "SyncBridge — export all clients"
echo "Version tag: $VERSION"
echo "Git:         $GIT_SHA"
echo "Targets:     ${TARGETS[*]}"

if want web; then
  run_target "Web" "$ROOT/scripts/build-web.sh"
fi

if want android; then
  run_target "Android" "$ROOT/scripts/build-android-apk.sh"
fi

has_full_xcode() {
  command -v xcodebuild >/dev/null || return 1
  local xv
  xv="$(xcodebuild -version 2>/dev/null || true)"
  [[ "$xv" =~ ^Xcode[[:space:]][0-9]+(\.[0-9]+)? ]]
}

if want macos; then
  if has_full_xcode; then
    run_target "macOS" "$ROOT/scripts/build-macos-dmg.sh" Release
  else
  echo "  SKIP macOS — full Xcode required (not just Command Line Tools)"
    FAILURES+=("macos (no Xcode)")
  fi
fi

if want ios; then
  if has_full_xcode; then
    run_target "iOS" "$ROOT/scripts/build-ios-ipa.sh" Release
  else
    echo "  SKIP iOS — full Xcode + signing required"
    FAILURES+=("ios (no Xcode)")
  fi
fi

if want backend; then
  if command -v go >/dev/null; then
    run_target "Backend" "$ROOT/scripts/build-backend.sh"
  else
    echo "  SKIP Backend — Go not installed"
    FAILURES+=("backend (no Go)")
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Artifacts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

record_artifact "$RELEASES/android/SyncBridge-release.apk" "Android APK (release)"
record_artifact "$RELEASES/android/SyncBridge-debug.apk" "Android APK (debug)"
record_artifact "$RELEASES/macos/SyncBridge-Release.dmg" "macOS DMG"
record_artifact "$RELEASES/ios/SyncBridge-Release.ipa" "iOS IPA"
record_artifact "$RELEASES/web" "Web static site"
record_artifact "$RELEASES/SyncBridge-web.tar.gz" "Web tarball"
record_artifact "$RELEASES/backend/syncbridge-api-linux-amd64" "Backend API (linux amd64)"

{
  echo "SyncBridge Release Manifest"
  echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "Version:   $VERSION"
  echo "Git:       $GIT_SHA"
  echo ""
  echo "platform | path | size | checksum"
  echo "---------|------|------|----------"
  cat "$MANIFEST.tmp"
} > "$MANIFEST"
rm -f "$MANIFEST.tmp"

echo ""
echo "Manifest: $MANIFEST"
cat "$MANIFEST"

echo ""
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "Completed with failures: ${FAILURES[*]}"
else
  echo "All exports succeeded → $RELEASES/"
fi

README="$RELEASES/README.md"
cat > "$README" <<EOF
# SyncBridge Releases

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
Version: \`$VERSION\`  
Git: \`$GIT_SHA\`

## Artifacts

| Platform | File | Install |
|----------|------|---------|
| **Web** | \`web/\` or \`SyncBridge-web.tar.gz\` | Deploy to nginx / static host |
| **Android** | \`android/SyncBridge-release.apk\` | Sideload / \`adb install\` |
| **macOS** | \`macos/SyncBridge-Release.dmg\` | Open DMG → drag to Applications |
| **iOS** | \`ios/SyncBridge-Release.ipa\` | Xcode Devices or AltStore |
| **Backend** | \`backend/syncbridge-api-linux-amd64\` | Copy to VPS, run with PostgreSQL |

See \`MANIFEST.txt\` for checksums.

## Rebuild

\`\`\`bash
./scripts/export-all.sh          # everything
./scripts/export-all.sh web      # web only
./scripts/export-all.sh android  # APK only
\`\`\`

## Requirements

- **Web:** Node.js 20+
- **Android:** Android SDK (Android Studio)
- **macOS / iOS:** Xcode + XcodeGen (\`brew install xcodegen\`)
- **Backend:** Go 1.22+
EOF

echo "Readme:  $README"
[[ ${#FAILURES[@]} -gt 0 ]] && exit 1
exit 0
