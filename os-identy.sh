#!/bin/bash

echo "==================== SYSTEM OVERVIEW ===================="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Date: $(date)"

# OS Info
echo -e "\n--- OS ---"
grep '^PRETTY_NAME' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"'
uname -r && uname -m

# CPU Info
echo -e "\n--- CPU ---"
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU\(s\)|MHz'

# Memory
echo -e "\n--- MEMORY ---"
free -h

# Disk
echo -e "\n--- DISK ---"
df -hT /

echo -e "\nBlock devices:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Network
echo -e "\n--- NETWORK ---"
ip a | grep inet | grep -v '127.0.0.1'
echo "Default gateway: $(ip route | grep default | awk '{print $3}')"

# Public IP + country
echo -e "\n--- PUBLIC IP ---"
IP_JSON=$(curl -s https://ifconfig.io/all.json)
echo "IP: $(echo "$IP_JSON" | grep -oP '"ip":\s*"\K[^"]*')"
echo "Country: $(echo "$IP_JSON" | grep -oP '"country":\s*"\K[^"]*')"
echo "Country Code: $(echo "$IP_JSON" | grep -oP '"country_code":\s*"\K[^"]*')"

# Check virtualization
echo -e "\n--- VIRTUALIZATION ---"
if command -v systemd-detect-virt &>/dev/null; then
    systemd-detect-virt
else
    grep -q 'hypervisor' /proc/cpuinfo && echo "Hypervisor detected" || echo "Probably bare metal"
fi

# PCI devices
#echo -e "\n--- PCI DEVICES ---"
#lspci | grep -E "VGA|3D|Ethernet"

# DMI info (if available)
if [ -r /sys/class/dmi/id/product_name ]; then
    echo -e "\n--- HARDWARE INFO ---"
    echo "Manufacturer: $(cat /sys/class/dmi/id/sys_vendor)"
    echo "Product: $(cat /sys/class/dmi/id/product_name)"
    echo "Serial: $(cat /sys/class/dmi/id/product_serial)"
fi

# Ping test
echo -e "\n--- NETWORK LATENCY TEST ---"
ping -c 5 8.8.8.8 | tail -2

# Boot logs (last lines)
echo -e "\n--- dmesg (last 10 lines) ---"
dmesg | tail -10

echo -e "\n✅ Done"
