#!/bin/bash

set -euo pipefail

readonly VOLUME_STEP=0.05
readonly BRIGHTNESS_STEP=5
readonly MAX_VOLUME=1.0
readonly NOTIFICATION_TIMEOUT=1000
readonly SHOW_TEXT=false  # Set to false to hide text indicators

parse_volume() {
    local vol=${1#* }
    vol=${vol%% *}
    echo "$((10#${vol%%.*} * 100 + 10#${vol#*.}))" "${1##* }"
}

notify() {
    if [[ "$SHOW_TEXT" == true ]]; then
        exec notify-send --app-name="$1" --expire-time="$NOTIFICATION_TIMEOUT" --transient \
            --hint="string:x-canonical-private-synchronous:$2" \
            --hint="string:x-dunst-stack-tag:$2" \
            --hint="int:value:$3" "$4"
    else
        exec notify-send --app-name="$1" --expire-time="$NOTIFICATION_TIMEOUT" --transient \
            --hint="string:x-canonical-private-synchronous:$2" \
            --hint="string:x-dunst-stack-tag:$2" \
            --hint="int:value:$3" ""
    fi
}

volume_up() {
    wpctl set-mute @DEFAULT_SINK@ 0
    read -r vol muted <<< "$(parse_volume "$(wpctl get-volume @DEFAULT_SINK@)")"
    wpctl set-volume @DEFAULT_SINK@ "$(awk -v v="$vol" -v s="$VOLUME_STEP" -v m="$MAX_VOLUME" 'BEGIN {r=v/100+s; print (r>m)?m:r}')"
    read -r vol muted <<< "$(parse_volume "$(wpctl get-volume @DEFAULT_SINK@)")"
    notify "Volume" "volume" "$vol" "${vol}%"
}

volume_down() {
    wpctl set-volume @DEFAULT_SINK@ "${VOLUME_STEP}-"
    read -r vol muted <<< "$(parse_volume "$(wpctl get-volume @DEFAULT_SINK@)")"
    notify "Volume" "volume" "$vol" "${vol}%"
}

volume_mute() {
    wpctl set-mute @DEFAULT_SINK@ toggle
    read -r vol muted <<< "$(parse_volume "$(wpctl get-volume @DEFAULT_SINK@)")"
    [[ "$muted" == "[MUTED]" ]] && notify "Volume Mute" "volume" 0 "Muted" || notify "Volume" "volume" "$vol" "${vol}%"
}

mic_mute() {
    wpctl set-mute @DEFAULT_SOURCE@ toggle
    [[ "$(wpctl get-volume @DEFAULT_SOURCE@)" == *"[MUTED]"* ]] && notify "Microphone" "microphone" 0 "Microphone Muted" || notify "Microphone" "microphone" 100 "Microphone Unmuted"
}

brightness_up() {
    brightnessctl set "${BRIGHTNESS_STEP}%+" >/dev/null
    local b=$(($(brightnessctl get) * 100 / $(brightnessctl max)))
    notify "Brightness" "brightness" "$b" "${b}%"
}

brightness_down() {
    brightnessctl set "${BRIGHTNESS_STEP}%-" >/dev/null
    local b=$(($(brightnessctl get) * 100 / $(brightnessctl max)))
    notify "Brightness" "brightness" "$b" "${b}%"
}

next_track() {
    playerctl next
    sleep 0.8
    local meta=$(playerctl metadata --format '{{title}}|{{artist}}' 2>/dev/null)
    [[ -n "$meta" ]] && exec notify-send --app-name="Music Player" --expire-time="$NOTIFICATION_TIMEOUT" \
        --transient --hint="string:x-dunst-stack-tag:music_notif" "${meta%%|*}" "${meta#*|}"
}

prev_track() {
    playerctl previous
    sleep 0.8
    local meta=$(playerctl metadata --format '{{title}}|{{artist}}' 2>/dev/null)
    [[ -n "$meta" ]] && exec notify-send --app-name="Music Player" --expire-time="$NOTIFICATION_TIMEOUT" \
        --transient --hint="string:x-dunst-stack-tag:music_notif" "${meta%%|*}" "${meta#*|}"
}

play_pause() {
    playerctl play-pause && sleep 0.1
    local meta=$(playerctl metadata --format '{{title}}|{{artist}}' 2>/dev/null)
    [[ -n "$meta" ]] && exec notify-send --app-name="Music Player" --expire-time="$NOTIFICATION_TIMEOUT" \
        --transient --hint="string:x-dunst-stack-tag:music_notif" "${meta%%|*}" "${meta#*|}"
}

case "${1:-}" in
    volume_up) volume_up ;;
    volume_down) volume_down ;;
    volume_mute) volume_mute ;;
    mic_mute) mic_mute ;;
    brightness_up) brightness_up ;;
    brightness_down) brightness_down ;;
    next_track) next_track ;;
    prev_track) prev_track ;;
    play_pause) play_pause ;;
    *) echo "Usage: $0 {volume_up|volume_down|volume_mute|mic_mute|brightness_up|brightness_down|next_track|prev_track|play_pause}" >&2; exit 1 ;;
esac