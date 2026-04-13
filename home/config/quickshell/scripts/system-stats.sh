#!/bin/sh

set -eu

state_dir="${XDG_RUNTIME_DIR:-/tmp}"
if [ ! -w "$state_dir" ]; then
    state_dir="/tmp"
fi
state_file="$state_dir/rbw-quickshell-cpu.stat"

is_uint() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat

total=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle_total=$((idle + iowait))
cpu_pct=0

if [ -f "$state_file" ]; then
    read -r prev_total prev_idle < "$state_file" || true
    if [ -n "${prev_total:-}" ] && [ -n "${prev_idle:-}" ]; then
        diff_total=$((total - prev_total))
        diff_idle=$((idle_total - prev_idle))
        if [ "$diff_total" -gt 0 ]; then
            cpu_pct=$(((100 * (diff_total - diff_idle) + (diff_total / 2)) / diff_total))
        fi
    fi
fi

printf '%s %s\n' "$total" "$idle_total" > "$state_file"

mem_total_kb=$(awk '/MemTotal:/ { print $2 }' /proc/meminfo)
mem_available_kb=$(awk '/MemAvailable:/ { print $2 }' /proc/meminfo)
mem_used_kb=$((mem_total_kb - mem_available_kb))
ram_pct=$(((100 * mem_used_kb + (mem_total_kb / 2)) / mem_total_kb))

gpu_pct="null"
gpu_mem_pct="null"
gpu_temp="null"
gpu_mem_used_mib="null"
gpu_mem_total_mib="null"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia_line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1 || true)
    if [ -n "$nvidia_line" ]; then
        nvidia_util=$(printf '%s' "$nvidia_line" | awk -F',' '{gsub(/ /, "", $1); print $1}')
        nvidia_mem_used=$(printf '%s' "$nvidia_line" | awk -F',' '{gsub(/ /, "", $2); print $2}')
        nvidia_mem_total=$(printf '%s' "$nvidia_line" | awk -F',' '{gsub(/ /, "", $3); print $3}')
        nvidia_temp=$(printf '%s' "$nvidia_line" | awk -F',' '{gsub(/ /, "", $4); print $4}')

        if is_uint "$nvidia_util"; then
            gpu_pct="$nvidia_util"
        fi

        if is_uint "$nvidia_mem_used" && is_uint "$nvidia_mem_total" && [ "$nvidia_mem_total" -gt 0 ]; then
            gpu_mem_pct=$(((100 * nvidia_mem_used + (nvidia_mem_total / 2)) / nvidia_mem_total))
            gpu_mem_used_mib="$nvidia_mem_used"
            gpu_mem_total_mib="$nvidia_mem_total"
        fi

        if is_uint "$nvidia_temp"; then
            gpu_temp="$nvidia_temp"
        fi
    fi
fi

read_hwmon_temp() {
    hwmon_dir=$1
    shift

    for pattern in "$@"; do
        for label_path in "$hwmon_dir"/temp*_label; do
            [ -r "$label_path" ] || continue
            label=$(tr '[:upper:]' '[:lower:]' < "$label_path" 2>/dev/null || printf '')
            case "$label" in
                *"$pattern"*)
                    input_path="${label_path%_label}_input"
                    if [ -r "$input_path" ]; then
                        raw_temp=$(cat "$input_path" 2>/dev/null || printf '')
                        if is_uint "$raw_temp" && [ "$raw_temp" -gt 0 ]; then
                            printf '%s' $(((raw_temp + 500) / 1000))
                            return 0
                        fi
                    fi
                    ;;
            esac
        done
    done

    for input_path in "$hwmon_dir"/temp*_input; do
        [ -r "$input_path" ] || continue
        raw_temp=$(cat "$input_path" 2>/dev/null || printf '')
        if is_uint "$raw_temp" && [ "$raw_temp" -gt 0 ]; then
            printf '%s' $(((raw_temp + 500) / 1000))
            return 0
        fi
    done

    return 1
}

cpu_temp="null"
for hwmon in /sys/class/hwmon/hwmon*; do
    [ -d "$hwmon" ] || continue
    hwmon_name=$(cat "$hwmon/name" 2>/dev/null || printf '')
    case "$hwmon_name" in
        coretemp|k10temp|zenpower|cpu_thermal|x86_pkg_temp)
            if temp_value=$(read_hwmon_temp "$hwmon" "package id" "tctl" "tdie" "cpu" "package"); then
                cpu_temp="$temp_value"
                break
            fi
            ;;
    esac
done

if [ "$cpu_temp" = "null" ]; then
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -d "$zone" ] || continue
        zone_type=$(tr '[:upper:]' '[:lower:]' < "$zone/type" 2>/dev/null || printf '')
        case "$zone_type" in
            *cpu*|*pkg*|*x86_pkg_temp*|*k10temp*|*tdie*|*tctl*)
                raw_temp=$(cat "$zone/temp" 2>/dev/null || printf '')
                if is_uint "$raw_temp" && [ "$raw_temp" -gt 0 ]; then
                    cpu_temp=$(((raw_temp + 500) / 1000))
                    break
                fi
                ;;
        esac
    done
fi

for device in /sys/class/drm/card*/device; do
    [ -d "$device" ] || continue

    if [ "$gpu_pct" = "null" ] && [ -r "$device/gpu_busy_percent" ]; then
        gpu_busy=$(cat "$device/gpu_busy_percent" 2>/dev/null || printf '')
        if is_uint "$gpu_busy"; then
            gpu_pct="$gpu_busy"
        fi
    fi

    if [ "$gpu_mem_pct" = "null" ] && [ -r "$device/mem_info_vram_used" ] && [ -r "$device/mem_info_vram_total" ]; then
        vram_used=$(cat "$device/mem_info_vram_used" 2>/dev/null || printf '0')
        vram_total=$(cat "$device/mem_info_vram_total" 2>/dev/null || printf '0')
        if is_uint "$vram_used" && is_uint "$vram_total" && [ "$vram_total" -gt 0 ]; then
            gpu_mem_pct=$(((100 * vram_used + (vram_total / 2)) / vram_total))
            gpu_mem_used_mib=$(((vram_used + 524288) / 1048576))
            gpu_mem_total_mib=$(((vram_total + 524288) / 1048576))
        fi
    fi

    if [ "$gpu_temp" = "null" ]; then
        for hwmon in "$device"/hwmon/hwmon*; do
            [ -d "$hwmon" ] || continue
            if temp_value=$(read_hwmon_temp "$hwmon" "edge" "junction" "gpu" "mem"); then
                gpu_temp="$temp_value"
                break 2
            fi
        done
    fi
done

ram_used_gib=$(awk -v used="$mem_used_kb" 'BEGIN { printf "%.1f", used / 1048576 }')
ram_total_gib=$(awk -v total="$mem_total_kb" 'BEGIN { printf "%.1f", total / 1048576 }')

printf '{"cpu":%s,"gpu":%s,"gpuMemory":%s,"ram":%s,"cpuTemp":%s,"gpuTemp":%s,"ramUsedGiB":%s,"ramTotalGiB":%s,"gpuMemoryUsedMiB":%s,"gpuMemoryTotalMiB":%s}\n' \
    "$cpu_pct" \
    "$gpu_pct" \
    "$gpu_mem_pct" \
    "$ram_pct" \
    "$cpu_temp" \
    "$gpu_temp" \
    "$ram_used_gib" \
    "$ram_total_gib" \
    "$gpu_mem_used_mib" \
    "$gpu_mem_total_mib"
