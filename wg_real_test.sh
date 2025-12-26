#!/usr/bin/env bash

SERVER="1.1.1.1"
DOWNLOAD_URL="https://speed.cloudflare.com/__down?bytes=300000000"
PING_INTERVAL=0.2
PING_COUNT=20

echo "=============================="
echo " WireGuard REAL performance test"
echo "=============================="
echo

### MTU
echo "[1/5] MTU check"
ip link show | grep -E "wg|tun" | awk '{print $2,$5}'
echo

### Base ping
echo "[2/5] Base latency test"
ping -c $PING_COUNT -i $PING_INTERVAL $SERVER | tee /tmp/ping_base.txt
BASE_AVG=$(grep rtt /tmp/ping_base.txt | awk -F'/' '{print $5}')
BASE_JITTER=$(grep rtt /tmp/ping_base.txt | awk -F'/' '{print $7}')
echo "Base avg: ${BASE_AVG} ms"
echo "Base jitter: ${BASE_JITTER} ms"
echo

### Download + ping
echo "[3/5] Load test (HTTPS download + ping)"
ping -i $PING_INTERVAL $SERVER > /tmp/ping_load.txt &
PING_PID=$!

curl -L -o /dev/null $DOWNLOAD_URL

kill $PING_PID
wait $PING_PID 2>/dev/null

LOAD_AVG=$(grep rtt /tmp/ping_load.txt | tail -1 | awk -F'/' '{print $5}')
LOAD_JITTER=$(grep rtt /tmp/ping_load.txt | tail -1 | awk -F'/' '{print $7}')

echo "Load avg: ${LOAD_AVG} ms"
echo "Load jitter: ${LOAD_JITTER} ms"
echo

### Analysis
echo "[4/5] Analysis"
DELTA_PING=$(echo "$LOAD_AVG - $BASE_AVG" | bc -l)
DELTA_JITTER=$(echo "$LOAD_JITTER - $BASE_JITTER" | bc -l)

printf "Ping delta: %.2f ms\n" "$DELTA_PING"
printf "Jitter delta: %.2f ms\n" "$DELTA_JITTER"
echo

### Verdict
echo "[5/5] Verdict"
if (( $(echo "$DELTA_PING < 10" | bc -l) )) && (( $(echo "$DELTA_JITTER < 5" | bc -l) )); then
  echo "✅ OK: VPN suitable for gaming"
else
  echo "❌ BAD: bufferbloat / MTU / qdisc problem"
  echo "   → Check MTU, fq, offloading"
fi

echo
echo "Done."
