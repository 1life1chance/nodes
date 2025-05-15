#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

INSTALL_DIR=~/pipe
BIN_NAME=pop
CONFIG=$INSTALL_DIR/config.json
LOG_FILE=$INSTALL_DIR/pop.log

# Обновление и зависимости
sudo apt update -y && sudo apt install -y figlet whiptail curl screen wget

# Приветствие
clear
echo -e "${PINK}$(figlet -w 150 -f standard \"Softs by The Gentleman\")${NC}"
echo "============================================================================================================================="
echo "Добро пожаловать! Пока идёт установка, подпишись на мой Telegram-канал:"
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

# Установка
install_node() {
  mkdir -p $INSTALL_DIR/download_cache
  cd $INSTALL_DIR || exit

  INVITE=$(whiptail --inputbox "Введите ваш invite code:" 10 60 --title "Invite Code" 3>&1 1>&2 2>&3)
  SOLANA=$(whiptail --inputbox "Введите ваш Solana-адрес:" 10 60 --title "Solana" 3>&1 1>&2 2>&3)
  RAM=$(whiptail --inputbox "RAM (в ГБ) под кэш:" 10 60 --title "RAM" 3>&1 1>&2 2>&3)
  DISK=$(whiptail --inputbox "Диск (в ГБ) под кэш:" 10 60 --title "Disk" 3>&1 1>&2 2>&3)

  NAME=$(whiptail --inputbox "Имя вашей ноды:" 10 60 --title "Node name" 3>&1 1>&2 2>&3)
  EMAIL=$(whiptail --inputbox "Email:" 10 60 --title "Email" 3>&1 1>&2 2>&3)
  SITE=$(whiptail --inputbox "Сайт (https://...):" 10 60 --title "Website" 3>&1 1>&2 2>&3)
  TG=$(whiptail --inputbox "Telegram (@...):" 10 60 --title "Telegram" 3>&1 1>&2 2>&3)
  DISCORD=$(whiptail --inputbox "Discord (name#0000):" 10 60 --title "Discord" 3>&1 1>&2 2>&3)
  TWITTER=$(whiptail --inputbox "Twitter (@...):" 10 60 --title "Twitter" 3>&1 1>&2 2>&3)

  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    BIN_URL="https://dl.pipecdn.app/v0.2.8/pop"
  elif [[ "$ARCH" == "aarch64" ]]; then
    BIN_URL="https://dl.pipecdn.app/v0.2.8/pop-arm64"
  else
    echo -e "${RED}Неизвестная архитектура: $ARCH${NC}"
    exit 1
  fi

  wget -O $BIN_NAME "$BIN_URL" && chmod +x $BIN_NAME

  cat > $CONFIG <<EOF
{
  "pop_name": "$NAME",
  "pop_location": "Earth, Internet",
  "invite_code": "$INVITE",
  "server": { "host": "0.0.0.0", "port": 443, "http_port": 80, "workers": 0 },
  "cache_config": {
    "memory_cache_size_mb": $((RAM * 1024)),
    "disk_cache_path": "./download_cache",
    "disk_cache_size_gb": $DISK,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": { "base_url": "https://dataplane.pipenetwork.com" },
  "identity_config": {
    "node_name": "$NAME",
    "name": "$NAME",
    "email": "$EMAIL",
    "website": "$SITE",
    "twitter": "$TWITTER",
    "discord": "$DISCORD",
    "telegram": "$TG",
    "solana_pubkey": "$SOLANA"
  }
}
EOF

  screen -S popnode -dm bash -c "export POP_CONFIG_PATH=$CONFIG && ./$BIN_NAME | tee $LOG_FILE"
  echo -e "${GREEN}Нода установлена и запущена в screen сессии 'popnode'.${NC}"
}

# Проверка
check_status() {
  if screen -list | grep -q popnode; then
    echo -e "${GREEN}Нода работает в screen 'popnode'${NC}"
  else
    echo -e "${RED}Нода не запущена.${NC}"
  fi
}

# Лог
show_log() {
  if [[ -f $LOG_FILE ]]; then
    echo -e "${CYAN}Последние 50 строк лога:${NC}"
    tail -n 50 $LOG_FILE
    if grep -q "500 Internal Server Error" "$LOG_FILE"; then
      echo -e "\n${YELLOW}⚠️ Обнаружена ошибка 500 от API Pipe. Это не критично. Просто подождите — проблема на их стороне.${NC}"
    fi
  else
    echo -e "${RED}Файл лога не найден.${NC}"
  fi
}

# Войти в screen
attach_screen() {
  screen -r popnode
}

# Перезапуск
restart_node() {
  screen -S popnode -X quit || true
  screen -S popnode -dm bash -c "export POP_CONFIG_PATH=$CONFIG && ./$BIN_NAME | tee $LOG_FILE"
  echo -e "${GREEN}Нода перезапущена.${NC}"
}

# Меню
animate_loading
CHOICE=$(whiptail --title "PIPE Node Меню" \
  --menu "Выберите действие:" 20 60 10 \
  "1" "Установить ноду" \
  "2" "Проверить статус" \
  "3" "Показать лог (50 строк)" \
  "4" "Зайти в screen" \
  "5" "Перезапустить ноду" \
  "6" "Выход" \
  3>&1 1>&2 2>&3)

case $CHOICE in
  1) install_node ;;
  2) check_status ;;
  3) show_log ;;
  4) attach_screen ;;
  5) restart_node ;;
  6) echo -e "${CYAN}Выход.${NC}" ;;
  *) echo -e "${RED}Неверный выбор.${NC}" ;;
esac
