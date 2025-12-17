#!/bin/bash
# YABS Network Only (IPv4) -------— FINAL FIXED VERSION

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

# ---------- uptime (YABS style) ----------
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

# ---------- IP info ----------
IPINFO=$($DL http://ip-api.com/json)
echo
echo "IPv4 Network Information:"
echo "---------------------------------"
echo "ISP        : $(echo "$IPINFO" | awk -F'"' '/"isp"/{print $4}')"
echo "ASN        : $(echo "$IPINFO" | awk -F'"' '/"as"/{print $4}')"
echo "Host       : $(echo "$IPINFO" | awk -F'"' '/"org"/{print $4}')"
echo "Location   : $(echo "$IPINFO" | awk -F'"' '/"city"/{c=$4} /"regionName"/{r=$4} /"region"/{rc=$4} END{print c", "r" ("rc")"}')"
echo "Country    : $(echo "$IPINFO" | awk -F'"' '/"country"/{print $4}')"

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

  SEND=$(timeout 15 iperf3 -4 -c "$HOST" -P 8 2>/dev/null | grep SUM | grep receiver | awk '{print $6,$7}')
  RECV=$(timeout 15 iperf3 -4 -c "$HOST" -P 8 -R 2>/dev/null | grep SUM | grep receiver | awk '{print $6,$7}')
  PING=$(ping -4 -c1 "$HOST" 2>/dev/null | sed -n 's/.*time=\(.*\) ms/\1 ms/p')

  [[ -z "$SEND" ]] && SEND="busy"
  [[ -z "$RECV" ]] && RECV="busy"
  [[ -z "$PING" ]] && PING="--"

  printf "%-15s | %-25s | %-15s | %-15s | %-10s\n" "$NAME" "$LOC" "$SEND" "$RECV" "$PING"
done

echo
echo "Completed in $(( $(date +%s) - START_TIME )) sec"
unset LC_ALL
