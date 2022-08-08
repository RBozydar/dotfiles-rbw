#!/usr/bin/env bash
# for m in $(polybar --list-monitors | cut -d":" -f1); do
#     MONITOR=$m polybar --reload example &
# done
# else
#   polybar --reload top -c ~/.config/polybar/config &
# fi


pkill polybar &
killall -q polybar &

# Pause while killall completes
while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done

PRIMARY=$(xrandr --query | grep " connected" | grep "primary" | cut -d" " -f1)
OTHERS=$(xrandr --query | grep " connected" | grep -v "primary" | cut -d" " -f1)

for bar in top bottom; do
    MONITOR=$PRRIMARY polybar --reload $bar &
    done

for m in $OTHERS; do
# for m in $(polybar --list-monitors | cut -d":" -f1); do
    for bar in top bottom; do
    MONITOR=$m polybar --reload $bar &
    done
done

