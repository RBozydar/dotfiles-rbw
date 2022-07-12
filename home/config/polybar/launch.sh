#!/usr/bin/env bash

# Terminate already running bar instances
#killall -q polybar

# Wait until the processes have been shut down
#while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar1 and bar2
#polybar bar1 &
#polybar bar2 &
#echo "Bars launched..."



# # Terminate any currently running instances
# killall -q polybar

# # Pause while killall completes
# while pgrep -u $UID -x polybar > /dev/null; do sleep 1; done

# for m in $(polybar --list-monitors | cut -d":" -f1); do
#     MONITOR=$m polybar --reload example &
# done
# else
#   polybar --reload top -c ~/.config/polybar/config &
# fi

# # Launch bar(s)
# #polybar topDP -q &
# polybar topDVI -q &
# #polybar botDP -q &
# polybar botDVI -q &
# echo "polybars launched..."


pkill polybar
polybar -r main &

for m in $(polybar --list-monitors | cut -d":" -f1); do
    for bar in ['top' ,'bottom']; do
    MONITOR=$m polybar --reload $bar &
    done
done

