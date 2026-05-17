#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

bat=$(upower -e 2>/dev/null | grep '/battery_' | head -n 1)

if [ -n "$bat" ]; then
    upower -i "$bat" 2>/dev/null | awk '
        /percentage:/ { print "BAT=" $2 }
        /state:/ { print "BAT_STATE=" $2 }
    '
else
    echo "BAT="
    echo "BAT_STATE="
fi

vol=$(timeout 2 wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)

if [ -n "$vol" ]; then
    printf '%s\n' "$vol" | awk '
        {
            volume = $2 * 100
            muted = ""

            for (i = 3; i <= NF; i++) {
                if ($i ~ /MUTED/)
                    muted = "1"
            }

            printf "VOL=%d\nVOL_MUTED=%s\n", volume + 0.5, muted
        }
    '
elif command -v pactl >/dev/null 2>&1; then
    vol_percent=$(timeout 2 pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+%$/) {
                    gsub("%", "", $i)
                    print $i
                    exit
                }
            }
        }
    ')

    if [ -n "$vol_percent" ]; then
        echo "VOL=$vol_percent"
    else
        echo "VOL="
    fi

    muted=$(timeout 2 pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '
        /yes/ { print "1"; found = 1 }
        /no/ { print ""; found = 1 }
        END { if (!found) print "" }
    ')

    echo "VOL_MUTED=$muted"
else
    echo "VOL="
    echo "VOL_MUTED="
fi

if command -v brightnessctl >/dev/null 2>&1; then
    brightnessctl -m 2>/dev/null | awk -F, '{
        gsub("%", "", $4)
        print "BRI=" $4
    }'
else
    backlight_dir=/sys/class/backlight/intel_backlight

    if [ -r "$backlight_dir/brightness" ] && [ -r "$backlight_dir/max_brightness" ]; then
        read -r current < "$backlight_dir/brightness"
        read -r maximum < "$backlight_dir/max_brightness"

        awk -v current="$current" -v maximum="$maximum" 'BEGIN {
            if (maximum > 0)
                printf "BRI=%d\n", (current / maximum * 100) + 0.5
            else
                print "BRI="
        }'
    else
        echo "BRI="
    fi
fi
