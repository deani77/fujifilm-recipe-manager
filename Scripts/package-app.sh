#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
build_dir="${RECIPE_BUILD_PATH:-$PWD/.build}"
swift_flags=(-c release --scratch-path "$build_dir")
if [[ "${RECIPE_DISABLE_PACKAGE_SANDBOX:-0}" == "1" ]]; then swift_flags+=(--disable-sandbox); fi
swift build "${swift_flags[@]}"
bin_dir="$(swift build "${swift_flags[@]}" --show-bin-path)"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/recipe-manager-package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app_path="$staging_dir/Fujifilm Recipe Manager.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$bin_dir/RecipeManager" "$app_path/Contents/MacOS/RecipeManager"
cp Packaging/Info.plist "$app_path/Contents/Info.plist"
# Sign outside synced folders, which can attach Finder metadata to loose bundles.
xattr -cr "$app_path"
codesign --force --sign - --entitlements Packaging/RecipeManager.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"
archive_path="$output_dir/Fujifilm-Recipe-Manager-macOS-$(uname -m).zip"
ditto --norsrc -c -k --keepParent "$app_path" "$archive_path"
echo "$archive_path"
