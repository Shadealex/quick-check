#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Squid Universal Monitor $(date) ===${NC}"

# 1. Определяем порты Squid
echo -e "\n${YELLOW}=== Поиск портов Squid ===${NC}"
SQUID_PORTS=$(ss -tlnp | grep squid | awk '{print $4}' | cut -d: -f2 | sort -u)
if [ -z "$SQUID_PORTS" ]; then
    # Альтернативный поиск через netstat
    SQUID_PORTS=$(netstat -tlnp 2>/dev/null | grep squid | awk '{print $4}' | cut -d: -f2 | sort -u)
fi

if [ -z "$SQUID_PORTS" ]; then
    echo -e "${RED}Squid порты не найдены. Пробуем стандартные...${NC}"
    SQUID_PORTS="3128 8080 8888"
else
    echo -e "${GREEN}Найдены Squid порты: $SQUID_PORTS${NC}"
fi

# 2. Определяем внешние IP адреса сервера
echo -e "\n${YELLOW}=== Определение внешних IP адресов ===${NC}"
EXTERNAL_IPS=$(ip route get 8.8.8.8 2>/dev/null | grep -oE 'src [0-9.]+' | cut -d' ' -f2)
ALL_IPS=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

# Объединяем и убираем дубликаты
UNIQUE_IPS=$(echo -e "$EXTERNAL_IPS\n$ALL_IPS" | grep -v '^$' | sort -u)

echo -e "${GREEN}Найденные IP адреса:${NC}"
for ip in $UNIQUE_IPS; do
    echo "  - $ip"
done

# 3. Получаем статистику по каждому порту Squid
echo -e "\n${YELLOW}=== Статистика Squid по портам ===${NC}"
WORKING_PORTS=""
for port in $SQUID_PORTS; do
    echo -e "\n${BLUE}Порт $port:${NC}"
    
    # Проверяем доступность порта
    if timeout 10 squidclient -p $port mgr:info >/dev/null 2>&1; then
        WORKING_PORTS="$WORKING_PORTS $port"
        
        # Получаем статистику
        REQUESTS=$(squidclient -p $port mgr:counters 2>/dev/null | grep 'client_http.requests' | awk '{print $3}')
        ACTIVE=$(squidclient -p $port mgr:active_requests 2>/dev/null | grep -c 'uri' 2>/dev/null || echo "0")
        MEMORY=$(squidclient -p $port mgr:mem 2>/dev/null | grep 'Total accounted' | awk '{print $4,$5}')
        
        echo "  Requests: ${REQUESTS:-N/A}"
        echo "  Active: $ACTIVE"
        echo "  Memory: ${MEMORY:-N/A}"
        
        # Кеш статистика
        CACHE_HIT=$(squidclient -p $port mgr:info 2>/dev/null | grep "Hits as % of all requests" | tail -1)
        if [ ! -z "$CACHE_HIT" ]; then
            echo "  Cache: $CACHE_HIT"
        fi
        
    else
        echo -e "  ${RED}Порт недоступен или не является Squid${NC}"
    fi
done

if [ -z "$WORKING_PORTS" ]; then
    echo -e "${RED}Рабочие порты Squid не найдены!${NC}"
    exit 1
fi

# 4. Анализ сетевых соединений по портам
#echo -e "\n${YELLOW}=== Сетевые соединения по портам Squid ===${NC}"
#for port in $WORKING_PORTS; do
#    echo -e "\n${BLUE}Порт $port:${NC}"
#    CONNECTIONS=$(ss -tn | grep ":$port " | awk '{print $1}' | sort | uniq -c)
#    if [ ! -z "$CONNECTIONS" ]; then
#        echo "$CONNECTIONS"
#    else
#        echo "  Нет активных соединений"
#    fi
#done

# 5. Определяем исходящие IP из активных соединений
#echo -e "\n${YELLOW}=== Анализ исходящих соединений ===${NC}"
#OUTGOING_IPS=$(ss -tn | grep ESTAB | grep -v '127.0.0.1' | awk '{print $3}' | cut -d: -f1 | sort -u)

#if [ ! -z "$OUTGOING_IPS" ]; then
#    echo -e "${GREEN}Используемые исходящие IP:${NC}"
#    for ip in $OUTGOING_IPS; do
#        count=$(ss -tn | grep ESTAB | grep "$ip:" | wc -l)
#        printf "%-15s: %3d connections" $ip $count
        
        # Проверяем, есть ли этот IP в нашем списке серверных IP
#        if echo "$UNIQUE_IPS" | grep -q "$ip"; then
#            echo -e " ${GREEN}[Server IP]${NC}"
#        else
#            echo -e " ${YELLOW}[External/Other]${NC}"
#        fi
#    done
#else
#    echo -e "${RED}Исходящие соединения не найдены${NC}"
#fi

# 6. Топ назначений
echo -e "\n${YELLOW}=== Топ-10 назначений ===${NC}"
ss -tn | grep ESTAB | grep -v '127.0.0.1' | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10

# 7. Проверка балансировки (если есть несколько исходящих IP)
OUTGOING_COUNT=$(echo "$OUTGOING_IPS" | wc -w)
if [ $OUTGOING_COUNT -gt 1 ]; then
    echo -e "\n${YELLOW}=== Анализ балансировки нагрузки ===${NC}"Add commentMore actions
    
    # Вычисляем среднее количество соединений
    TOTAL_CONNECTIONS=0
    for ip in $OUTGOING_IPS; do
        count=$(ss -tn | grep ESTAB | grep "$ip:" | wc -l)
        TOTAL_CONNECTIONS=$((TOTAL_CONNECTIONS + count))
    done
    
    AVERAGE=$((TOTAL_CONNECTIONS / OUTGOING_COUNT))
    echo "Среднее соединений на IP: $AVERAGE"
    
    echo "Отклонение от среднего:"
    for ip in $OUTGOING_IPS; do
        count=$(ss -tn | grep ESTAB | grep "$ip:" | wc -l)
        deviation=$((count - AVERAGE))
        if [ $deviation -gt $((AVERAGE / 2)) ]; then
            echo -e "  $ip: ${RED}+$deviation (перегружен)${NC}"
        elif [ $deviation -lt $((AVERAGE / -2)) ]; then
            echo -e "  $ip: ${YELLOW}$deviation (недогружен)${NC}"
        else
            echo -e "  $ip: ${GREEN}$deviation (норма)${NC}"
        fi
    done
fi

# 8. Системная информация
echo -e "\n${YELLOW}=== Системная информация ===${NC}"
echo "Load Average: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3"/"$2" ("$3/$2*100"%)"}')"

# 9. Процессы Squid
echo -e "\n${YELLOW}=== Процессы Squid ===${NC}"
ps aux | grep '[s]quid' | awk '{printf "PID: %-8s CPU: %-6s MEM: %-6s CMD: %s\n", $2, $3"%", $4"%", $11}'

echo -e "\n${BLUE}=== Мониторинг завершен ===${NC}"
