#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
output_dir="${1:-$project_root/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
work_dir="$(mktemp -d /tmp/DropShelf-package.XXXXXX)"
mounted=0
cleanup() {
    if [[ "$mounted" == 1 ]]; then hdiutil detach "$work_dir/mounted" >/dev/null; fi
    rm -rf "$work_dir"
}
trap cleanup EXIT

"$DEVELOPER_DIR/usr/bin/xcodebuild" -project "$project_root/SelfDrop.xcodeproj" \
    -scheme SelfDrop -configuration Release -derivedDataPath "$project_root/.build/dmg" \
    build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    > "$output_dir/build.log" 2>&1 || {
        tail -n 40 "$output_dir/build.log"
        exit 1
    }

app_source="$project_root/.build/dmg/Build/Products/Release/SelfDrop.app"
test -x "$app_source/Contents/MacOS/SelfDrop"
codesign --verify --deep --strict "$app_source"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_source/Contents/Info.plist")"
architecture="$(lipo -archs "$app_source/Contents/MacOS/SelfDrop" | tr ' ' '-')"
image_name="DropShelf-$version-$architecture.dmg"
mkdir -p "$work_dir/staging"
ditto "$app_source" "$work_dir/staging/DropShelf.app"
ln -s /Applications "$work_dir/staging/Applications"
cat > "$work_dir/staging/INSTALL.txt" <<'INSTALL'
DropShelf — development build

Drag DropShelf.app to Applications, then open it.
Requires macOS 27.2 or newer and a compatible Apple Silicon Mac.
Choose the screenshot save folder inside the app to enable automatic collection.
Removing shelf items never deletes original files.

This build is locally ad hoc signed, not Developer ID signed or notarized.
Gatekeeper may block it on another Mac. No security settings are changed by this installer.
Production memory/performance and all manual acceptance gates are not yet complete.
INSTALL
diskutil image create from --volumeName DropShelf --format UDZO \
    "$work_dir/staging" "$output_dir/$image_name"
hdiutil verify "$output_dir/$image_name"
mkdir -p "$work_dir/mounted"
hdiutil attach "$output_dir/$image_name" -readonly -nobrowse -mountpoint "$work_dir/mounted"
mounted=1
test -x "$work_dir/mounted/DropShelf.app/Contents/MacOS/SelfDrop"
test "$(readlink "$work_dir/mounted/Applications")" = /Applications
codesign --verify --deep --strict "$work_dir/mounted/DropShelf.app"
hdiutil detach "$work_dir/mounted"
mounted=0
(cd "$output_dir" && shasum -a 256 "$image_name" > "$image_name.sha256")
echo "Created and verified: $output_dir/$image_name"
