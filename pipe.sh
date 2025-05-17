#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

INSTALL_DIR="/opt/popcache"
BIN_NAME="pop"
CONFIG_FILE="config.json"

# Установка зависимостей
sudo apt update -y
sudo apt install -y curl figlet whiptail jq docker.io iptables-persistent wget

# Логотип
echo -e "${PINK}$(figlet -w 120 -f standard "Softs by The Gentleman")${NC}"
echo "============================================================================================================================="
echo "Добро пожаловать! Пока идёт установка, подпишись на Telegram-канал для новостей и поддержки:"
echo ""
echo "The Gentleman — https://t.me/GentleChron"
echo "============================================================================================================================="
echo ""
sleep 5

# Анимация
animate_loading() {
  for ((i = 1; i <= 3; i++)); do
    printf "\r${GREEN}Подгружаем меню${NC}."
    sleep 0.5
    printf "\r${GREEN}Подгружаем меню${NC}.."
    sleep 0.5
    printf "\r${GREEN}Подгружаем меню${NC}..."
    sleep 0.5
  done
  echo ""
}

# Установка ноды
install_node() {
  sudo mkdir -p $INSTALL_DIR && cd $INSTALL_DIR

  INVITE=$(whiptail --inputbox "Введите ваш invite-код:" 10 60 --title "Invite" 3>&1 1>&2 2>&3)
  NAME=$(whiptail --inputbox "Придумайте имя ноды:" 10 60 --title "Node name" 3>&1 1>&2 2>&3)
  NICK=$(whiptail --inputbox "Ваш ник или имя:" 10 60 --title "Name" 3>&1 1>&2 2>&3)
  TG=$(whiptail --inputbox "Telegram (без @):" 10 60 --title "Telegram" 3>&1 1>&2 2>&3)
  DISCORD=$(whiptail --inputbox "Discord (name#0000):" 10 60 --title "Discord" 3>&1 1>&2 2>&3)
  SITE=$(whiptail --inputbox "Ваш сайт/GitHub/Twitter:" 10 60 --title "Website" 3>&1 1>&2 2>&3)
  EMAIL=$(whiptail --inputbox "Ваш email:" 10 60 --title "Email" 3>&1 1>&2 2>&3)
  SOLANA=$(whiptail --inputbox "Solana-адрес:" 10 60 --title "Solana" 3>&1 1>&2 2>&3)
  RAM=$(whiptail --inputbox "Сколько RAM (в ГБ) выделить:" 10 60 --title "RAM" 3>&1 1>&2 2>&3)
  DISK=$(whiptail --inputbox "Сколько DISK (в ГБ) выделить:" 10 60 --title "DISK" 3>&1 1>&2 2>&3)

  response=$(curl -s http://ip-api.com/json)
  COUNTRY=$(echo "$response" | jq -r '.country')
  CITY=$(echo "$response" | jq -r '.city')
  LOCATION="$CITY, $COUNTRY"
  RAM_MB=$((RAM * 1024))

  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    URL="https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz"
  else
    URL="https://download.pipe.network/static/pop-v0.3.0-linux-arm64.tar.gz"
  fi

  wget -q "$URL" -O pop.tar.gz
  tar -xzf pop.tar.gz && rm pop.tar.gz
  chmod +x $BIN_NAME

  cat > $CONFIG_FILE <<EOF
{
  "pop_name": "$NAME",
  "pop_location": "$LOCATION",
  "invite_code": "$INVITE",
  "server": {"host": "0.0.0.0", "port": 443, "http_port": 80, "workers": 0},
  "cache_config": {
    "memory_cache_size_mb": $RAM_MB,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $DISK,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": { "base_url": "https://dataplane.pipenetwork.com" },
  "identity_config": {
    "node_name": "$NAME",
    "name": "$NICK",
    "email": "$EMAIL",
    "website": "$SITE",
    "discord": "$DISCORD",
    "telegram": "$TG",
    "solana_pubkey": "$SOLANA"
  }
}
EOF

  cat > Dockerfile <<EOF
FROM ubuntu:24.04
RUN apt update && apt install -y ca-certificates curl libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/popcache
COPY $BIN_NAME .
COPY $CONFIG_FILE .
RUN chmod +x ./$BIN_NAME
CMD ["./$BIN_NAME", "--config", "$CONFIG_FILE"]
EOF

  docker build -t popnode .
  docker run -d --name popnode -p 80:80 -p 443:443 --restart unless-stopped popnode

  echo -e "${GREEN}Нода установлена и запущена!${NC}"
}

# Проверка статуса
check_status() {
  if docker ps | grep -q popnode; then
    echo -e "${GREEN}Нода запущена в Docker контейнере 'popnode'.${NC}"
  else
    echo -e "${RED}Нода не запущена.${NC}"
  fi
}

# Показ логов
show_logs() {
  docker logs --tail 50 -f popnode
}

# Перезапуск
restart_node() {
  docker restart popnode
  echo -e "${GREEN}Нода перезапущена.${NC}"
}

# Удаление
remove_node() {
  docker stop popnode && docker rm popnode
  docker rmi popnode:latest
  sudo rm -rf $INSTALL_DIR
  sudo rm -f /etc/sysctl.d/99-popcache.conf
  sudo rm -f /etc/security/limits.d/popcache.conf
  sudo sysctl --system
  echo -e "${GREEN}Нода полностью удалена.${NC}"
}

# Меню
animate_loading
CHOICE=$(whiptail --title "PIPE Node Меню" \
  --menu "Выберите действие:" 20 60 10 \
  "1" "Установить ноду" \
  "2" "Показать лог (50 строк)" \
  "3" "Удалить ноду" \
  "4" "Проверить статус" \
  "5" "Перезапустить ноду" \
  "6" "Выход" \
  3>&1 1>&2 2>&3)

case $CHOICE in
  1) install_node ;;
  2) show_logs ;;
  3) remove_node ;;
  4) check_status ;;
  5) restart_node ;;
  6) echo -e "${CYAN}Выход.${NC}" ;;
  *) echo -e "${RED}Неверный выбор.${NC}" ;;
esac
