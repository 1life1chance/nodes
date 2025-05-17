#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

INSTALL_DIR=/opt/popcache
CONFIG=$INSTALL_DIR/config.json
BIN_NAME=pop
DOCKER_IMAGE=popnode
DOCKER_CONTAINER=popnode

# Приветствие
clear
echo -e "${PINK}$(figlet -w 150 -f standard \"Softs by The Gentleman\")${NC}"
echo "============================================================================================================================="
echo "Добро пожаловать! Пока идёт установка, подпишись на Telegram-канал для новостей и поддержки:"
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

install_node() {
  echo -e "${BLUE}Начинаем установку...${NC}"
  sudo apt update -y
  sudo apt install -y curl libssl-dev ca-certificates jq docker.io iptables iptables-persistent

  sudo mkdir -p $INSTALL_DIR && cd $INSTALL_DIR

  echo -e "${YELLOW}Введите invite-код:${NC}"
  read INVITE
  echo -e "${YELLOW}Придумайте имя для ноды:${NC}"
  read NODE_NAME
  echo -e "${YELLOW}Введите ваше имя или ник:${NC}"
  read USER_NAME
  echo -e "${YELLOW}Введите Telegram (@без_собачки):${NC}"
  read TELEGRAM
  echo -e "${YELLOW}Введите Discord (имя#0000):${NC}"
  read DISCORD
  echo -e "${YELLOW}Введите сайт / GitHub / Twitter ссылку:${NC}"
  read WEBSITE
  echo -e "${YELLOW}Введите email:${NC}"
  read EMAIL
  echo -e "${YELLOW}Введите Solana адрес:${NC}"
  read SOLANA
  echo -e "${YELLOW}Оперативная память (в ГБ):${NC}"
  read RAM
  echo -e "${YELLOW}Максимальный размер кэша на диске (в ГБ):${NC}"
  read DISK

  # Получаем локацию по IP
  response=$(curl -s http://ip-api.com/json)
  country=$(echo "$response" | jq -r '.country')
  city=$(echo "$response" | jq -r '.city')
  LOCATION="$city, $country"

  # Оптимизация сети
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

  # Загрузка бинарника
  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz"
  else
    URL="https://download.pipe.network/static/pop-v0.3.0-linux-arm64.tar.gz"
  fi
  wget -q "$URL" -O pop.tar.gz
  tar -xzf pop.tar.gz && rm pop.tar.gz
  chmod +x $BIN_NAME
  chmod 755 $INSTALL_DIR/$BIN_NAME

  MB=$(( RAM * 1024 ))
  cat > $CONFIG <<EOF
{
  "pop_name": "$NODE_NAME",
  "pop_location": "$LOCATION",
  "invite_code": "$INVITE",
  "server": {"host": "0.0.0.0", "port": 443, "http_port": 80, "workers": 0},
  "cache_config": {
    "memory_cache_size_mb": $MB,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $DISK,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {"base_url": "https://dataplane.pipenetwork.com"},
  "identity_config": {
    "node_name": "$NODE_NAME",
    "name": "$USER_NAME",
    "email": "$EMAIL",
    "website": "$WEBSITE",
    "discord": "$DISCORD",
    "telegram": "$TELEGRAM",
    "solana_pubkey": "$SOLANA"
  }
}
EOF

  # Освобождение портов
  for PORT in 80 443; do
    if sudo ss -tulpen | awk '{print $5}' | grep -q ":$PORT$"; then
      echo -e "${BLUE}Порт $PORT занят, освобождаем...${NC}"
      sudo fuser -k ${PORT}/tcp
      sleep 2
    fi
  done

  # Iptables
  sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  sudo sh -c "iptables-save > /etc/iptables/rules.v4"

  # Dockerfile
  cat > Dockerfile <<EOL
FROM ubuntu:24.04
RUN apt update && apt install -y \\
    ca-certificates \\
    curl \\
    libssl-dev \\
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/popcache
COPY pop .
COPY config.json .
RUN chmod +x ./pop
CMD ["./pop", "--config", "config.json"]
EOL

  docker build -t $DOCKER_IMAGE .
  cd ~

  docker run -d \
    --name $DOCKER_CONTAINER \
    -p 80:80 \
    -p 443:443 \
    --restart unless-stopped \
    $DOCKER_IMAGE

  echo -e "${GREEN}Установка завершена. Логи:${NC}"
  echo -e "${YELLOW}docker logs -f --tail 100 $DOCKER_CONTAINER${NC}"
  sleep 2
  docker logs -f --tail 100 $DOCKER_CONTAINER
}

view_logs() {
  docker logs -f --tail 100 $DOCKER_CONTAINER
}

check_status() {
  curl -sk https://localhost/state | jq
}

check_health() {
  curl -sk https://localhost/health | jq
}

restart_node() {
  docker restart $DOCKER_CONTAINER && docker logs -f --tail 100 $DOCKER_CONTAINER
}

remove_node() {
  docker stop $DOCKER_CONTAINER && docker rm $DOCKER_CONTAINER
  sudo rm -rf $INSTALL_DIR
  docker rmi $DOCKER_IMAGE:latest
  sudo rm -f /etc/sysctl.d/99-popcache.conf
  sudo sysctl --system
  sudo rm -f /etc/security/limits.d/popcache.conf
  echo -e "${GREEN}Нода удалена полностью.${NC}"
}

# Меню
animate_loading
CHOICE=$(whiptail --title "Меню установки PIPE Node" \
  --menu "Выберите действие:" 20 60 10 \
  "1" "Установить ноду" \
  "2" "Перезапуск ноды" \
  "3" "Показать логи" \
  "4" "Удалить ноду" \
  "5" "Проверка состояния" \
  "6" "Проверка здоровья" \
  "7" "Выход" \
  3>&1 1>&2 2>&3)

case $CHOICE in
  1) install_node ;;
  2) restart_node ;;
  3) view_logs ;;
  4) remove_node ;;
  5) check_status ;;
  6) check_health ;;
  7) echo -e "${CYAN}Выход.${NC}" ;;
  *) echo -e "${RED}Неверный выбор.${NC}" ;;
esac
