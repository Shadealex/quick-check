#!/bin/bash

START_TIME=$(date +%s)
TARGET="8.8.8.8"
PING_COUNT=10

# Сбор системной информации
OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
CPU=$(nproc)
RAM=$(free -h | awk '/Mem:/ { print $2 }')
DISK=$(df -h / | awk 'NR==2 { print $2 " total, " $4 " free" }')
IP_LOCAL=$(hostname -I | awk '{print $1}')

# Внешний IP и код страны
IP_INFO=$(curl -s https://ifconfig.io/all.json)
IP_PUBLIC=$(echo "$IP_INFO" | grep -oP '"ip":\s*"\K[^"]+')
COUNTRY_CODE=$(echo "$IP_INFO" | grep -oP '"country_code":\s*"\K[^"]+')

# Ping-тест
PING_OUT=$(ping -c $PING_COUNT $TARGET)
LOSS=$(echo "$PING_OUT" | grep -oP '\d+(?=% packet loss)')
AVG=$(echo "$PING_OUT" | grep 'rtt min/avg/max' | awk -F '/' '{print $5}')
MAX=$(echo "$PING_OUT" | grep 'rtt min/avg/max' | awk -F '/' '{print $6}')

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Вывод
echo "=== System Info ==="
echo "OS: $OS"
echo "CPU(s): $CPU"
echo "RAM: $RAM"
echo "Disk: $DISK"
#echo "Local IP: $IP_LOCAL"
echo "Public IP: $IP_PUBLIC"
echo "Default gateway: $(ip route | grep default | awk '{print $3}')"
echo "Country code: $COUNTRY_CODE"

echo
echo "=== Network Test ($TARGET) ==="
echo "Ping count: $PING_COUNT"
echo "Packet loss: ${LOSS:-N/A}%"
echo "Avg latency: ${AVG:-N/A} ms"
echo "Max latency: ${MAX:-N/A} ms"

echo
echo "✅ Completed in $ELAPSED seconds."

# Не оставлять следов в истории, если включено ignorespace
[ "$HISTCONTROL" = "ignorespace" ] && history -d $((HISTCMD-1))
