#!/usr/bin/env bash
# Resolve Android SDK path for Gradle builds.
resolve_android_sdk() {
  local android_dir="$1"
  local props="$android_dir/local.properties"
  local candidates=()

  [[ -n "${ANDROID_HOME:-}" ]] && candidates+=("$ANDROID_HOME")
  [[ -n "${ANDROID_SDK_ROOT:-}" ]] && candidates+=("$ANDROID_SDK_ROOT")
  candidates+=(
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    "/opt/android-sdk"
  )

  if [[ -f "$props" ]]; then
    local from_props
    from_props="$(grep '^sdk.dir=' "$props" 2>/dev/null | cut -d= -f2- | sed 's/\\:/:/g')"
    [[ -n "$from_props" && -d "$from_props" ]] && { echo "$from_props"; return 0; }
  fi

  for dir in "${candidates[@]}"; do
    [[ -d "$dir" ]] && { echo "$dir"; return 0; }
  done

  return 1
}

write_android_local_properties() {
  local android_dir="$1"
  local sdk="$2"
  local props="$android_dir/local.properties"
  local escaped="${sdk//:/\\:}"
  if [[ -f "$props" ]] && grep -q '^sdk.dir=' "$props"; then
    sed -i.bak "s|^sdk.dir=.*|sdk.dir=$escaped|" "$props"
    rm -f "$props.bak"
  else
    echo "sdk.dir=$escaped" >> "$props"
  fi
}
