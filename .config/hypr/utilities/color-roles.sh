#!/bin/bash
# waybar gets @accent from the slot picked in settings > colors (9 by default), quickshell and hyprland read the same file
css="$HOME/.cache/wal/colors-waybar.css"
[ -f "$css" ] || exit 0
slot="$(grep -o '"accent": *[0-9]*' "$HOME/.config/hypr/.color-roles.json" 2>/dev/null | grep -o '[0-9]*$')"
hex="$(sed -n "s/^@define-color color${slot:-9} \(#[0-9a-fA-F]*\);/\1/p" "$css")"
sed -i '/^@define-color accent /d' "$css"
printf '@define-color accent %s;\n' "$hex" >> "$css"
# waybar only watches style.css
s="$HOME/.config/waybar/style.css"
[ -f "$s" ] && dd if="$s" of="$s" conv=notrunc status=none
exit 0
