#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
build_dir="$project_dir/.build/$configuration"
module_cache="$project_dir/.build/ModuleCache"
output_dir="$project_dir/outputs"
app_dir="$output_dir/Wheel Filter.app"
contents_dir="$app_dir/Contents"
source_dir="$project_dir/Sources/WheelFilter"

sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
clang_path="$(xcrun --find clang)"

mkdir -p "$build_dir" "$module_cache" "$contents_dir/MacOS" "$contents_dir/Resources"

optimization=(-O2)
if [[ "$configuration" == "debug" ]]; then
    optimization=(-O0 -g)
fi

common_flags=(
    -fobjc-arc
    -fmodules
    -Wall
    -Wextra
    "-fmodules-cache-path=$module_cache"
    -isysroot "$sdk_path"
    -mmacosx-version-min=13.0
    -I "$source_dir"
)

"$clang_path" "${common_flags[@]}" "${optimization[@]}" \
    "$source_dir/WheelDebouncer.m" \
    "$project_dir/Tests/WheelDebouncerTests.m" \
    -framework Foundation \
    -o "$build_dir/WheelDebouncerTests"

"$build_dir/WheelDebouncerTests"

"$clang_path" "${common_flags[@]}" "${optimization[@]}" \
    "$source_dir/WheelDebouncer.m" \
    "$source_dir/main.m" \
    -framework AppKit \
    -framework ApplicationServices \
    -o "$contents_dir/MacOS/WheelFilter"

cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
codesign --force --sign - --identifier com.uroboros.WheelFilter "$app_dir"

echo "$app_dir"
