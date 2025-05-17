#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# Проверка наличия необходимых утилит
if ! command -v curl &> /dev/null; then
  sudo apt update -y && sudo apt install -y curl
fi

if ! command -v figlet &> /dev/null; then
  sudo apt update -y && sudo apt install -y figlet
fi

if ! command -v bc &> /dev/null; then
  sudo apt update -y && sudo apt install -y bc
fi

# Приветствие
clear
echo -e "${PINK}$(figlet -w 150 -f standard \"Softs by The Gentleman\")${NC}"
echo "============================================================================================================================="
echo "Добро пожаловать! Пока идёт установка, подпишись на мой Telegram-канал для новостей и поддержки:"
echo ""
echo "The Gentleman — https://t.me/GentleChron"
echo "============================================================================================================================="
echo ""
sleep 7

# Анимация
animate_loading() {
  for ((i = 1; i <= 3; i++)); do
    printf "\r${GREEN}Подгружаем меню${NC}."
    sleep 1
    printf "\r${GREEN}Подгружаем меню${NC}.."
    sleep 1
    printf "\r${GREEN}Подгружаем меню${NC}..."
    sleep 1
  done
  echo ""
}

animate_loading

# Меню
echo -e "${YELLOW}Выберите действие:${NC}"
echo -e "${CYAN}1) Установка ноды${NC}"
echo -e "${CYAN}2) Обновление ноды${NC}"
echo -e "${CYAN}3) Просмотр логов${NC}"
echo -e "${CYAN}4) Рестарт ноды${NC}"
echo -e "${CYAN}5) Проверка здоровья${NC}"
echo -e "${CYAN}6) Информация о ноде${NC}"
echo -e "${CYAN}7) Удаление ноды${NC}"

read -p "Введите номер: " choice

case $choice in
  1)
    sudo apt update && sudo apt install -y libssl-dev ca-certificates jq docker.io iptables iptables-persistent
    sudo usermod -aG docker "$USER"

    sudo mkdir -p /opt/popcache && cd /opt/popcache

    read -p "Введите ваш invite-код: " INVITE
    read -p "Придумайте имя для ноды: " POP_NODE
    read -p "Введите ваше имя/никнейм: " POP_NAME
    read -p "Telegram (без @): " TELEGRAM
    read -p "Discord: " DISCORD
    read -p "Сайт/GitHub/Twitter: " WEBSITE
    read -p "Email: " EMAIL
    read -p "Solana-кошелёк: " SOLANA_PUBKEY
    read -p "RAM (в ГБ): " RAM_GB
    read -p "Кеш на диске (в ГБ): " DISK_GB

    response=$(curl -s http://ip-api.com/json)
    country=$(echo "$response" | jq -r '.country')
    city=$(echo "$response" | jq -r '.city')
    POP_LOCATION="$city, $country"

    sudo bash -c 'cat > /etc/sysctl.d/99-popcache.conf << EOL
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL'
    sudo sysctl -p /etc/sysctl.d/99-popcache.conf

    sudo bash -c 'cat > /etc/security/limits.d/popcache.conf << EOL
*    hard nofile 65535
*    soft nofile 65535
EOL'

    ARCH=$(uname -m)
    URL="https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz"
    [ "$ARCH" = "aarch64" ] && URL="https://download.pipe.network/static/pop-v0.3.0-linux-arm64.tar.gz"

    wget -q "$URL" -O pop.tar.gz && tar -xzf pop.tar.gz && rm pop.tar.gz
    chmod +x pop && chmod 755 /opt/popcache/pop

    MB=$(( RAM_GB * 1024 ))
    cat > config.json <<EOL
{
  "pop_name": "$POP_NODE",
  "pop_location": "$POP_LOCATION",
  "invite_code": "$INVITE",
  "server": {"host": "0.0.0.0", "port": 443, "http_port": 80, "workers": 0},
  "cache_config": {"memory_cache_size_mb": $MB, "disk_cache_path": "./cache", "disk_cache_size_gb": $DISK_GB, "default_ttl_seconds": 86400, "respect_origin_headers": true, "max_cacheable_size_mb": 1024},
  "api_endpoints": {"base_url": "https://dataplane.pipenetwork.com"},
  "identity_config": {"node_name": "$POP_NODE", "name": "$POP_NAME", "email": "$EMAIL", "website": "$WEBSITE", "discord": "$DISCORD", "telegram": "$TELEGRAM", "solana_pubkey": "$SOLANA_PUBKEY"}
}
EOL

    for PORT in 80 443; do
      sudo fuser -k ${PORT}/tcp || true
    done

    if systemctl list-unit-files --type=service | grep -q '^apache2\.service'; then
      sudo systemctl stop apache2 || true
      sudo systemctl disable apache2 || true
    fi

    sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    cat > Dockerfile << EOL
FROM ubuntu:24.04
RUN apt update && apt install -y ca-certificates curl libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/popcache
COPY pop .
COPY config.json .
RUN chmod +x ./pop
CMD ["./pop", "--config", "config.json"]
EOL

    docker build -t popnode . && cd ~
    docker run -d --name popnode -p 80:80 -p 443:443 --restart unless-stopped popnode

    echo -e "${YELLOW}Команда для логов: docker logs --tail 100 -f popnode${NC}"
    docker logs --tail 100 -f popnode
    ;;
  2)
    echo -e "${GREEN}У вас уже актуальная версия ноды.${NC}"
    ;;
  3)
    docker logs --tail 100 -f popnode
    ;;
  4)
    docker restart popnode && docker logs --tail 100 -f popnode
    ;;
  5)
    curl -sk https://localhost/health | jq
    ;;
  6)
    curl -sk https://localhost/state | jq
    ;;
  7)
    docker stop popnode && docker rm popnode
    sudo rm -rf /opt/popcache
    docker rmi popnode:latest
    sudo rm -f /etc/sysctl.d/99-popcache.conf && sudo sysctl --system
    sudo rm -f /etc/security/limits.d/popcache.conf
    ;;
  *)
    echo -e "${RED}Неверный выбор!${NC}"
    ;;
esac
