#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

clear
sudo apt update -y && sudo apt install -y figlet whiptail curl docker.io jq ca-certificates libssl-dev

# Заголовок
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by The Gentleman")${NC}"
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
    sleep 0.5
    printf "\r${GREEN}Подгружаем меню${NC}.."
    sleep 0.5
    printf "\r${GREEN}Подгружаем меню${NC}..."
    sleep 0.5
  done
  echo ""
}

# Установка
install_node() {
  mkdir -p /opt/popcache && cd /opt/popcache

  INVITE=$(whiptail --inputbox "Введите invite-код:" 10 60 --title "Invite Code" 3>&1 1>&2 2>&3)
  NAME=$(whiptail --inputbox "Придумайте имя для ноды:" 10 60 --title "Node Name" 3>&1 1>&2 2>&3)
  NICK=$(whiptail --inputbox "Ваш ник или имя:" 10 60 --title "Your Name" 3>&1 1>&2 2>&3)
  TG=$(whiptail --inputbox "Telegram (без @):" 10 60 --title "Telegram" 3>&1 1>&2 2>&3)
  DISCORD=$(whiptail --inputbox "Discord (user#0000):" 10 60 --title "Discord" 3>&1 1>&2 2>&3)
  SITE=$(whiptail --inputbox "Сайт или GitHub/Twitter:" 10 60 --title "Website" 3>&1 1>&2 2>&3)
  EMAIL=$(whiptail --inputbox "Ваш email:" 10 60 --title "Email" 3>&1 1>&2 2>&3)
  SOLANA=$(whiptail --inputbox "Ваш Solana-адрес:" 10 60 --title "Solana" 3>&1 1>&2 2>&3)
  RAM=$(whiptail --inputbox "RAM в ГБ (например, 8):" 10 60 --title "RAM" 3>&1 1>&2 2>&3)
  DISK=$(whiptail --inputbox "Диск в ГБ (например, 250):" 10 60 --title "Disk" 3>&1 1>&2 2>&3)

  LOCATION=$(curl -s http://ip-api.com/json | jq -r '.city + ", " + .country')

  wget -q https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz -O pop.tar.gz
  tar -xzf pop.tar.gz && rm pop.tar.gz
  chmod +x pop

  cat > config.json <<EOF
{
  "pop_name": "$NAME",
  "pop_location": "$LOCATION",
  "invite_code": "$INVITE",
  "server": {"host": "0.0.0.0", "port": 443, "http_port": 80, "workers": 0},
  "cache_config": {"memory_cache_size_mb": $((RAM * 1024)), "disk_cache_path": "./cache", "disk_cache_size_gb": $DISK, "default_ttl_seconds": 86400, "respect_origin_headers": true, "max_cacheable_size_mb": 1024},
  "api_endpoints": {"base_url": "https://dataplane.pipenetwork.com"},
  "identity_config": {"node_name": "$NAME", "name": "$NICK", "email": "$EMAIL", "website": "$SITE", "discord": "$DISCORD", "telegram": "$TG", "solana_pubkey": "$SOLANA"}
}
EOF

  cat > Dockerfile << EOL
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

  docker build -t popnode .
  docker run -d --name popnode -p 80:80 -p 443:443 --restart unless-stopped popnode

  echo -e "${GREEN}Нода установлена и работает в контейнере popnode${NC}"
  echo -e "${CYAN}Логи: docker logs --tail 100 -f popnode${NC}"
  docker logs --tail 20 -f popnode
}

# Удаление
remove_node() {
  docker stop popnode && docker rm popnode
  docker rmi popnode:latest
  rm -rf /opt/popcache
  echo -e "${GREEN}Нода удалена.${NC}"
}

# Меню
animate_loading
CHOICE=$(whiptail --title "PIPE Node Меню" \
  --menu "Выберите действие:" 20 60 10 \
  "1" "Установить ноду" \
  "2" "Удалить ноду" \
  "3" "Логи (docker logs)" \
  "4" "Рестарт контейнера" \
  "5" "Выход" \
  3>&1 1>&2 2>&3)

case $CHOICE in
  1) install_node ;;
  2) remove_node ;;
  3) docker logs --tail 100 -f popnode ;;
  4) docker restart popnode && docker logs --tail 20 -f popnode ;;
  5) echo -e "${CYAN}Выход.${NC}" ;;
  *) echo -e "${RED}Неверный выбор.${NC}" ;;
esac
