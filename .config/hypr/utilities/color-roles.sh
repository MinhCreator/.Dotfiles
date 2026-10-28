#!/bin/bash
# every scheme (and every wallpaper on pywal) remembers its own role picks. took me way too long to get here
# no args loads them, set ROLE N picks one, reset wipes them
HYPR="$HOME/.config/hypr"
saved="$HYPR/.color-roles-saved.json"
active="$HYPR/.color-roles.json"
key="$(cat "$HYPR/.color-theme" 2>/dev/null)"
# color-apply writes wal/wal before calling this, picker/current only gets written after
[ "${key:-pywal}" = pywal ] && key="pywal:$(cat "$HOME/.cache/wal/wal" 2>/dev/null)"

# first run, whatever was picked before belongs to the applied scheme
[ -f "$saved" ] || jq -c --arg k "$key" '{($k): .}' "$active" > "$saved" 2>/dev/null || echo '{}' > "$saved"
case "$1" in
    set) f='.[$k][$r] = ($n | tonumber)' ;;
    reset) f='del(.[$k])' ;;
    *) f='.' ;;
esac
jq -c --arg k "$key" --arg r "$2" --arg n "${3:-0}" "$f" "$saved" > "$saved.tmp" && mv "$saved.tmp" "$saved"
jq -c --arg k "$key" '.[$k] // {}' "$saved" > "$active"

# waybar gets @accent from the slot picked (9 by default)
css="$HOME/.cache/wal/colors-waybar.css"
if [ -f "$css" ]; then
    slot="$(jq '.accent // 9' "$active")"
    hex="$(sed -n "s/^@define-color color$slot \(#[0-9a-fA-F]*\);/\1/p" "$css")"
    sed -i '/^@define-color accent /d' "$css"
    printf '@define-color accent %s;\n' "$hex" >> "$css"
    # waybar only watches style.css
    s="$HOME/.config/waybar/style.css"
    [ -f "$s" ] && dd if="$s" of="$s" conv=notrunc status=none
fi
# color-apply reloads on its own, a pick from settings needs it for the border
[ -n "$1" ] && hyprctl reload config-only >/dev/null 2>&1
exit 0
