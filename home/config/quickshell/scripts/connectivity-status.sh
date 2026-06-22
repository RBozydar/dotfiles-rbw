#!/bin/sh

set -eu

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

format_rate() {
	value=$1

	if [ "$value" -lt 1024 ]; then
		printf '%sB' "$value"
	elif [ "$value" -lt 1048576 ]; then
		awk -v value="$value" 'BEGIN { printf "%.0fK", value / 1024 }'
	elif [ "$value" -lt 1073741824 ]; then
		awk -v value="$value" 'BEGIN { if (value < 10485760) printf "%.1fM", value / 1048576; else printf "%.0fM", value / 1048576 }'
	else
		awk -v value="$value" 'BEGIN { printf "%.1fG", value / 1073741824 }'
	fi
}

state_dir="${XDG_RUNTIME_DIR:-/tmp}"
if [ ! -w "$state_dir" ]; then
	state_dir="/tmp"
fi

network_state_file="$state_dir/rbw-quickshell-network.stat"
network_label="offline"
network_kind="offline"
network_connected="false"
network_device=""
wifi_available="false"
wifi_enabled="false"
wifi_device=""
ethernet_available="false"
ethernet_connected="false"
ethernet_device=""
ethernet_label="unavailable"
network_up_rate="0B"
network_down_rate="0B"

if command -v nmcli >/dev/null 2>&1; then
	device_status=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null || true)
	network_line=$(printf '%s\n' "$device_status" | awk -F: '($3 == "connected" || $3 ~ /^connecting/) { print; exit }' || true)
	wifi_line=$(printf '%s\n' "$device_status" | awk -F: '($2 == "wifi" || $2 == "wireless" || $2 == "802-11-wireless") { print; exit }' || true)
	ethernet_line=$(printf '%s\n' "$device_status" | awk -F: '($2 == "ethernet" || $2 == "802-3-ethernet") { print; exit }' || true)
	wifi_radio=$(nmcli radio wifi 2>/dev/null | tail -n 1 || true)

	case "$wifi_radio" in
	enabled | on)
		wifi_enabled="true"
		;;
	esac

	if [ -n "$wifi_line" ]; then
		wifi_available="true"
		wifi_device=$(printf '%s' "$wifi_line" | awk -F: '{ print $1 }')
	fi

	if [ -n "$ethernet_line" ]; then
		ethernet_available="true"
		ethernet_device=$(printf '%s' "$ethernet_line" | awk -F: '{ print $1 }')
		ethernet_state=$(printf '%s' "$ethernet_line" | awk -F: '{ print $3 }')
		ethernet_connection=$(printf '%s' "$ethernet_line" | awk -F: '{ print $4 }')
		case "$ethernet_state" in
		connected | connecting*)
			ethernet_connected="true"
			ethernet_label="${ethernet_connection:-${ethernet_device:-ethernet}}"
			;;
		*)
			ethernet_label="${ethernet_device:-ethernet}"
			;;
		esac
	fi

	if [ -n "$network_line" ]; then
		network_device=$(printf '%s' "$network_line" | awk -F: '{ print $1 }')
		network_type=$(printf '%s' "$network_line" | awk -F: '{ print $2 }')
		network_state=$(printf '%s' "$network_line" | awk -F: '{ print $3 }')
		network_name=$(printf '%s' "$network_line" | awk -F: '{ print $4 }')

		if [ "$network_state" = "connecting" ] || printf '%s' "$network_state" | grep -q '^connecting'; then
			network_label="connecting"
			network_kind="connecting"
			network_connected="true"
		else
			case "$network_type" in
			wifi | wireless | 802-11-wireless)
				network_label="${network_name:-wifi}"
				network_kind="wifi"
				network_connected="true"
				;;
			ethernet | 802-3-ethernet)
				network_label="ethernet ${network_device:-wired}"
				network_kind="ethernet"
				network_connected="true"
				ethernet_connected="true"
				;;
			*)
				network_label="${network_name:-$network_type}"
				network_kind="$network_type"
				network_connected="true"
				;;
			esac
		fi
	fi
fi

if [ -n "$network_device" ] && [ -r "/sys/class/net/$network_device/statistics/rx_bytes" ] && [ -r "/sys/class/net/$network_device/statistics/tx_bytes" ]; then
	now=$(date +%s)
	current_rx=$(cat "/sys/class/net/$network_device/statistics/rx_bytes")
	current_tx=$(cat "/sys/class/net/$network_device/statistics/tx_bytes")

	if [ -f "$network_state_file" ]; then
		read -r saved_device saved_time saved_rx saved_tx <"$network_state_file" || true
		if [ "${saved_device:-}" = "$network_device" ] && [ -n "${saved_time:-}" ] && [ "$now" -gt "$saved_time" ]; then
			elapsed=$((now - saved_time))
			rx_rate=$(((current_rx - saved_rx) / elapsed))
			tx_rate=$(((current_tx - saved_tx) / elapsed))
			if [ "$rx_rate" -lt 0 ]; then
				rx_rate=0
			fi
			if [ "$tx_rate" -lt 0 ]; then
				tx_rate=0
			fi
			network_down_rate=$(format_rate "$rx_rate")
			network_up_rate=$(format_rate "$tx_rate")
		fi
	fi

	printf '%s %s %s %s\n' "$network_device" "$now" "$current_rx" "$current_tx" >"$network_state_file"
fi

bluetooth_label="off"
bluetooth_available="false"
bluetooth_enabled="false"
bluetooth_count=0

if command -v bluetoothctl >/dev/null 2>&1; then
	bluetooth_show=$(bluetoothctl show 2>/dev/null || true)

	if printf '%s\n' "$bluetooth_show" | grep -q '^Controller '; then
		bluetooth_available="true"
	fi

	if printf '%s\n' "$bluetooth_show" | grep -q 'Powered: yes'; then
		bluetooth_enabled="true"
		bluetooth_devices=$(bluetoothctl devices Connected 2>/dev/null || true)
		bluetooth_count=$(printf '%s\n' "$bluetooth_devices" | awk 'NF { count++ } END { print count + 0 }')

		if [ "$bluetooth_count" -eq 1 ]; then
			bluetooth_label=$(printf '%s\n' "$bluetooth_devices" | sed -n '1s/^Device [^ ]* //p')
		elif [ "$bluetooth_count" -gt 1 ]; then
			bluetooth_label="$bluetooth_count devices"
		else
			bluetooth_label="ready"
		fi
	else
		if printf '%s\n' "$bluetooth_show" | grep -q '^Controller '; then
			bluetooth_label="off"
		else
			bluetooth_label="unavailable"
		fi
	fi
fi

printf '{"networkLabel":"%s","networkKind":"%s","networkConnected":%s,"wifiAvailable":%s,"wifiEnabled":%s,"wifiDevice":"%s","ethernetAvailable":%s,"ethernetConnected":%s,"ethernetDevice":"%s","ethernetLabel":"%s","networkUpRate":"%s","networkDownRate":"%s","bluetoothLabel":"%s","bluetoothAvailable":%s,"bluetoothEnabled":%s,"bluetoothCount":%s}\n' \
	"$(json_escape "$network_label")" \
	"$(json_escape "$network_kind")" \
	"$network_connected" \
	"$wifi_available" \
	"$wifi_enabled" \
	"$(json_escape "$wifi_device")" \
	"$ethernet_available" \
	"$ethernet_connected" \
	"$(json_escape "$ethernet_device")" \
	"$(json_escape "$ethernet_label")" \
	"$(json_escape "$network_up_rate")" \
	"$(json_escape "$network_down_rate")" \
	"$(json_escape "$bluetooth_label")" \
	"$bluetooth_available" \
	"$bluetooth_enabled" \
	"$bluetooth_count"
