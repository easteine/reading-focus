#!/bin/bash
# Manually test whether disabling the space-switching gestures takes effect live.
#
#   ./scripts/test-swipe-block.sh off    # save current values, set all to 0
#   (try swiping with 3 and 4 fingers, left/right and up)
#   ./scripts/test-swipe-block.sh on     # restore saved values
#
# Mirrors what GestureBlocker.swift does during a session.
set -e

BACKUP="$HOME/.readingfocus-swipe-test-backup"
TRACKPAD_DOMAINS=(com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad)
TRACKPAD_KEYS=(TrackpadThreeFingerHorizSwipeGesture TrackpadFourFingerHorizSwipeGesture
               TrackpadThreeFingerVertSwipeGesture TrackpadFourFingerVertSwipeGesture)
GLOBAL_KEYS=(com.apple.trackpad.threeFingerHorizSwipeGesture com.apple.trackpad.fourFingerHorizSwipeGesture
             com.apple.trackpad.threeFingerVertSwipeGesture com.apple.trackpad.fourFingerVertSwipeGesture)

activate() {
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
}

# Calls $1 with: <host-flag> <domain> <key> for every pref.
each_pref() {
    for d in "${TRACKPAD_DOMAINS[@]}"; do
        for k in "${TRACKPAD_KEYS[@]}"; do "$1" "" "$d" "$k"; done
    done
    for k in "${GLOBAL_KEYS[@]}"; do "$1" "-currentHost" NSGlobalDomain "$k"; done
}

save_one()    { echo "$1|$2|$3|$(defaults $1 read "$2" "$3" 2>/dev/null || echo absent)" >> "$BACKUP"; }
disable_one() { defaults $1 write "$2" "$3" -int 0; }

case "$1" in
    off)
        if [ -f "$BACKUP" ]; then
            echo "Backup already exists at $BACKUP — run '$0 on' first."; exit 1
        fi
        each_pref save_one
        each_pref disable_one
        activate
        echo "Gestures set to 0. Try swiping now."
        ;;
    on)
        [ -f "$BACKUP" ] || { echo "No backup at $BACKUP — nothing to restore."; exit 1; }
        while IFS='|' read -r host domain key value; do
            if [ "$value" = absent ]; then
                defaults $host delete "$domain" "$key" 2>/dev/null || true
            else
                defaults $host write "$domain" "$key" -int "$value"
            fi
        done < "$BACKUP"
        rm "$BACKUP"
        activate
        echo "Gestures restored."
        ;;
    *)
        echo "Usage: $0 off|on"; exit 1
        ;;
esac
