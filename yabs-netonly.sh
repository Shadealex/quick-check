#!/bin/bash
# Minimal YABS (Network Only)
# Based on Yet-Another-Bench-Script by Mason Rowe
# Stripped to: System Info + IPv4 Info + iperf3 IPv4

set -e

echo "-----------------------------------------------"
echo "   YABS Network Only (IPv4)"
echo "-----------------------------------------------"
date
START_TIME=$(date +%s)

# locale
export LC_ALL=C

# arch
ARCH=$(uname -m)
if [[ $ARCH == *x86_64* ]]; then
  ARCH="x64"
elif [[ $ARCH == *aarch64* || $ARCH == *arm* ]]; then
  ARCH="aarch64"
else
  echo "Unsupported architecture"
  exit 1
fi

# tools
command -v curl >/dev/null 2>&1 && DL="curl -s" || DL="wget -qO-"
command -v iperf3 >/dev/null 2>&1 || {
  echo "iperf3 not found"
  exit 1
}

# IPv4 check
ping -4 -c1 -W2 8.8.8.8 >/dev/null 2>&1 || {
  echo "No IPv4 connectivity"
  exit 1
}

echo
echo "Basic System Information"
echo "-----------------------------------------------"

UPTIME=$(uptime -p)
CPU=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
CORES=$(nproc)
FREQ=$(awk -F: '/cpu MHz/ {print int($2); exit}' /proc/cpuinfo)
RAM=$(free -h | awk '/Mem:/ {print $2}')
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
VIRT=$(systemd-detect-virt 2>/dev/null || echo unknown)

echo "Uptime     : $UPTIME"
echo "CPU        : $CPU"
echo "Cores      : $CORES @ ${FREQ}MHz"
echo "RAM        : $RAM"
echo "Distro     : $DISTRO"
echo "Kernel     : $KERNEL"
echo "VM Type    : ${VIRT^^}"

echo
echo "IPv4 Network Information"
echo "-----------------------------------------------"

IPINFO=$($DL http://ip-api.com/json)
echo "ISP        : $(echo "$IPINFO" | jq -r .isp)"
echo "ASN        : $(echo "$IPINFO" | jq -r .as)"
echo "Country    : $(echo "$IPINFO" | jq -r .country)"
echo "Region     : $(echo "$IPINFO" | jq -r .regionName)"
echo "City       : $(echo "$IPINFO" | jq -r .city)"

echo
echo "iperf3 Network Speed Tests (IPv4)"
echo "-----------------------------------------------"
printf "%-15s | %-25s | %-12s | %-12s | %-8s\n" "Provider" "Location" "Send" "Recv" "Ping"
printf "%-15s | %-25s | %-12s | %-12s | %-8s\n" "--------" "--------" "----" "----" "----"

IPERF_SERVERS=(
  "lon.speedtest.clouvider.net|Clouvider|London, UK (10G)"
  "speedtest.nyc1.us.leaseweb.net|Leaseweb|NYC, US (10G)"
)

for S in "${IPERF_SERVERS[@]}"; do
  HOST=$(echo "$S" | cut -d\| -f1)
  NAME=$(echo "$S" | cut -d\| -f2)
  LOC=$(echo "$S" | cut -d\| -f3)

  SEND=$(iperf3 -4 -c "$HOST" -P 8 -t 10 2>/dev/null | grep SUM | grep receiver | awk '{print $6,$7}')
  RECV=$(iperf3 -4 -c "$HOST" -P 8 -t 10 -R 2>/dev/null | grep SUM | grep receiver | awk '{print $6,$7}')
  PING=$(ping -4 -c1 "$HOST" 2>/dev/null | grep time= | sed 's/.*time=//')

  [[ -z "$SEND" ]] && SEND="busy"
  [[ -z "$RECV" ]] && RECV="busy"
  [[ -z "$PING" ]] && PING="--"

  printf "%-15s | %-25s | %-12s | %-12s | %-8s\n" "$NAME" "$LOC" "$SEND" "$RECV" "$PING"
done

END_TIME=$(date +%s)
echo
echo "Completed in $((END_TIME - START_TIME)) seconds"

unset LC_ALL
