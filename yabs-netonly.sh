#!/bin/bash
# YABS Network Only (IPv4) — FINAL STABLE VERSION
# Compatible output, no disk / geekbench / ipv6

export LC_ALL=C

echo "-----------------------------------------------"
echo "   YABS Network Only (IPv4)"
echo "-----------------------------------------------"
date
START_TIME=$(date +%s)

# ---------- downloader ----------
if command -v curl >/dev/null 2>&1; then
  DL="curl -s"
elif command -v wget >/dev/null 2>&1; then
  DL="wget -qO-"
else
  echo "curl or wget required"
  exit 1
fi

# ---------- iperf ----------
if ! command -v iperf3 >/dev/null 2>&1; then
  echo "iperf3 required"
  exit 1
fi

# ---------- IPv4 ----------
if ! ping -4 -c1 -W2 ipv4.google.com >/dev/null 2>&1; then
  echo "IPv4 not available"
  exit 1
fi

# ---------- uptime (classic YABS style) ----------
UPTIME=$(uptime | awk -F'( |,|:)+' '{d=h=m=0;
 if ($7=="min") m=$6;
 else {
  if ($7~/^day/) {d=$6;h=$8;m=$9}
  else {h=$6;m=$7}
 }
 print d+0,"days,",h+0,"hours,",m+0,"minutes"}')

# ---------- CPU ----------
CPU_PROC=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
CPU_CORES=$(nproc)
CPU_FREQ=$(awk -F: '/cpu MHz/ {print int($2); exit}' /proc/cpuinfo)" MHz"
grep -q aes /proc/cpuinfo && CPU_AES="✔ Enabled" || CPU_AES="❌ Disabled"
grep -Eq 'vmx|svm' /proc/cpuinfo && CPU_VIRT="✔ Enabled" || CPU_VIRT="❌ Disabled"

# ---------- memory / disk ----------
TOTAL_RAM=$(free | awk 'NR==2 {printf "%.1f GiB", $2/1024/1024}')
TOTAL_SWAP=$(free | awk '/Swap/ {printf "%.1f GiB", $2/1024/1024}')
TOTAL_DISK=$(df -k --total | awk '/total/ {printf "%.1f TiB", $2/1024/1024/1024}')

# ---------- OS ----------
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
VIRT=$(systemd-detect-virt 2>/dev/null)
[[ -z "$VIRT" || "$VIRT" == "none" ]] && VIRT="NONE"

echo
echo "Basic System Information:"
echo "---------------------------------"
echo "Uptime     : $UPTIME"
echo "Processor  : $CPU_PROC"
echo "CPU cores  : $CPU_CORES @ $CPU_FREQ"
echo "AES-NI     : $CPU_AES"
echo "VM-x/AMD-V : $CPU_VIRT"
echo "RAM        : $TOTAL_RAM"
echo "Swap       : $TOTAL_SWAP"
echo "Disk       : $TOTAL_DISK"
echo "Distro     : $DISTRO"
echo "Kernel     : $KERNEL"
echo "VM Type    : $VIRT"
echo "IPv4/IPv6  : ✔ Online / ❌ Offline"

# ---------- IPv4 Network Info (SAFE JSON PARSE) ----------
IPINFO=$($DL http://ip-api.com/json)

json_val() {
  echo "$IPINFO" \
    | sed 's/[{},]/\n/g' \
    | awk -F: -v k="$1" '$1 ~ "\""k"\"" {
        gsub(/^[ \t"]+|[ \t"]+$/, "", $2)
        print $2
      }'
}

ISP=$(json_val isp)
ASN=$(json_val as)
ORG=$(json_val org)
CITY=$(json_val city)
REGION=$(json_val regionName)
REGION_CODE=$(json_val region)
COUNTRY=$(json_val country)

echo
echo "IPv4 Network Information:"
echo "---------------------------------"
echo "ISP        : ${ISP:-Unknown}"
echo "ASN        : ${ASN:-Unknown}"
echo "Host       : ${ORG:-Unknown}"
echo "Location   : ${CITY:-Unknown}, ${REGION:-Unknown} (${REGION_CODE:-??})"
echo "Country    : ${COUNTRY:-Unknown}"

# ---------- Cloudflare Speed Test ----------
echo
echo "Cloudflare Speed Test (IPv4):"
echo "---------------------------------"

CF_SERVER="speed.cloudflare.com"

PING_LINE=$(ping -4 -c 5 "$CF_SERVER" 2>/dev/null | tail -1)
CF_PING=$(echo "$PING_LINE" | awk -F'/' '{print $5}')
CF_JITTER=$(echo "$PING_LINE" | awk -F'/' '{print $7}')

CF_DL_BYTES=$(curl -4 -s -o /dev/null \
  https://speed.cloudflare.com/__down?bytes=10000000 \
  -w "%{speed_download}")

CF_UL_BYTES=$(dd if=/dev/zero bs=1M count=10 2>/dev/null \
  | curl -4 -s -o /dev/null \
    https://speed.cloudflare.com/__up \
    --data-binary @- \
    -w "%{speed_upload}")

# bytes/sec → Mbps
CF_DL_Mbps=$(awk "BEGIN { printf \"%.2f\", $CF_DL_BYTES * 8 / 1000000 }")
CF_UL_Mbps=$(awk "BEGIN { printf \"%.2f\", $CF_UL_BYTES * 8 / 1000000 }")

echo "Download   : ${CF_DL_Mbps:-N/A} Mbps"
echo "Upload     : ${CF_UL_Mbps:-N/A} Mbps"
echo "Ping       : ${CF_PING:-N/A} ms"
echo "Jitter     : ${CF_JITTER:-N/A} ms"

# ---------- iperf servers ----------
IPERF_LOCS=(
  "lon.speedtest.clouvider.net|Clouvider|London, UK (10G)"
  "iperf-ams-nl.eranium.net|Eranium|Amsterdam, NL (100G)"
  "speedtest.uztelecom.uz|Uztelecom|Tashkent, UZ (10G)"
  "speedtest.sin1.sg.leaseweb.net|Leaseweb|Singapore, SG (10G)"
  "la.speedtest.clouvider.net|Clouvider|Los Angeles, CA, US (10G)"
  "speedtest.nyc1.us.leaseweb.net|Leaseweb|NYC, NY, US (10G)"
  "speedtest.sao1.edgoo.net|Edgoo|Sao Paulo, BR (1G)"
)

echo
echo "iperf3 Network Speed Tests (IPv4):"
echo "---------------------------------"
printf "%-15s | %-25s | %-15s | %-15s | %-10s\n" "Provider" "Location (Link)" "Send Speed" "Recv Speed" "Ping"
printf "%-15s | %-25s | %-15s | %-15s | %-10s\n" "-----" "-----" "----" "----" "----"

for S in "${IPERF_LOCS[@]}"; do
  HOST=${S%%|*}
  TMP=${S#*|}
  NAME=${TMP%%|*}
  LOC=${TMP#*|}

  SEND=$(timeout 15 iperf3 -4 -c "$HOST" -P 8 2>/dev/null \
         | grep SUM | grep receiver | awk '{print $6,$7}')

  RECV=$(timeout 15 iperf3 -4 -c "$HOST" -P 8 -R 2>/dev/null \
         | grep SUM | grep receiver | awk '{print $6,$7}')

  PING=$(ping -4 -c1 "$HOST" 2>/dev/null \
         | sed -n 's/.*time=\(.*\) ms/\1 ms/p')

  [[ -z "$SEND" ]] && SEND="busy"
  [[ -z "$RECV" ]] && RECV="busy"
  [[ -z "$PING" ]] && PING="--"

  printf "%-15s | %-25s | %-15s | %-15s | %-10s\n" \
         "$NAME" "$LOC" "$SEND" "$RECV" "$PING"
done

echo
echo "Completed in $(( $(date +%s) - START_TIME )) sec"
unset LC_ALL
