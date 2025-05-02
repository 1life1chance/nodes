#!/bin/bash

# Проверка и установка необходимых утилит
for util in figlet whiptail curl docker iptables jq; do
  if ! command -v $util &>/dev/null; then
    echo "$util не найден. Устанавливаем..."
    sudo apt update && sudo apt install -y $util
  fi
done

# Цвета и стили
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
BLINK="\e[5m"
NO_BLINK="\e[25m"
LINK_START="\e]8;;https://t.me/GentleChron\a"
LINK_END="\e]8;;\a"
NC="\e[0m"

# Приветствие
echo -e "${CYAN}$(figlet -w 150 -f standard \"Soft by The Gentleman\")${NC}"
echo "============================================================================"
echo "        Добро пожаловать в мастер установки ноды Aztec от Джентльмена       "
echo "============================================================================"

# Мигающий призыв подписаться
echo
echo -e "${BLINK}${YELLOW}Подписывайтесь на мой Telegram-канал, пока идёт загрузка скрипта:${NC} ${LINK_START}${CYAN}GentleChron${NC}${LINK_END}${BLINK}${NO_BLINK}"
echo -e "${CYAN}Продолжение через 10 секунд...${NC}"
sleep 10

# Анимация загрузки
animate() {
  for i in {1..3}; do
    printf "\r${GREEN}Загрузка${NC}%s" "$(printf '.%.0s' $(seq 1 $i))"
    sleep 0.4
  done
  echo
}
animate

# Главное меню
CHOICE=$(whiptail --title "Aztec Node Control" \
  --menu "Выберите действие:" 16 60 5 \
  "1" "Установить ноду" \
  "2" "Показать логи" \
  "3" "Получить хеш" \
  "4" "Зарегистрировать валидатора" \
  "5" "Удалить ноду" \
  3>&1 1>&2 2>&3)

# Функция благодарности
say_thanks() {
  echo
echo -e "${CYAN}Спасибо за доверие, всегда рад видеть вас у себя в канале: ${LINK_START}${YELLOW}GentleChron${NC}${LINK_END}${CYAN}.${NC}"  
}

case "$CHOICE" in
  1)
    echo -e "${GREEN}Подготавливаю сервер и подгружаю все нужные файлы...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y build-essential git jq lz4 make nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev clang bsdmainutils ncdu unzip
    if ! command -v docker &>/dev/null; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER"
    fi
    sudo chmod 666 /var/run/docker.sock
    sudo iptables -I INPUT -p tcp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    mkdir -p "$HOME/aztec-sequencer"
    cd "$HOME/aztec-sequencer" || exit

    # Определяем последний тег Aztec-образа
    echo -e "${YELLOW}Проверка последней ноды...${NC}"
    LATEST_TAG=$(curl -s "https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=100" \
      | jq -r '.results[].name' \
      | grep -E '^0\..*-alpha-testnet\.[0-9]+' \
      | sort -V \
      | tail -1)
    [ -z "$LATEST_TAG" ] && LATEST_TAG="alpha-testnet"
    echo -e "${GREEN}Используем тег: ${LATEST_TAG}${NC}"

    docker pull aztecprotocol/aztec:${LATEST_TAG}

    read -p "Введи RPC Sepolia URL: " RPC_URL
    read -p "Введи Beacon Sepolia URL: " CONS_URL
    read -p "Введи свой приватный ключ: " PRIV_KEY
    read -p "Введи адрес кошелька: " WALLET_ADDR

    SERVER_IP=$(curl -s https://api.ipify.org)

    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC_URL
L1_CONSENSUS_HOST_URLS=$CONS_URL
VALIDATOR_PRIVATE_KEY=$PRIV_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET_ADDR
EOF

    echo -e "${GREEN}Запускаем контейнер...${NC}"
    docker run -d \
      --name aztec-sequencer \
      --network host \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:${LATEST_TAG} \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    say_thanks
    ;;
  2)
    echo -e "${GREEN}Показ логов контейнера:${NC}"
    docker logs --tail 100 -f aztec-sequencer
    say_thanks
    ;;
  3)
    echo -e "${GREEN}Получение хеша...${NC}"
    cd "$HOME/aztec-sequencer" || exit 1
    [ -f .env ] && export $(grep -v '^#' .env | xargs)
    tmpf=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/byGentleman/Softs/main/aztec/get-hash.sh > "$tmpf"
    bash "$tmpf"
    rm -f "$tmpf"
    say_thanks
    ;;
  4)
    echo -e "${GREEN}Регистрация валидатора...${NC}"
    cd "$HOME/aztec-sequencer" || exit 1
    [ -f .env ] && export $(grep -v '^#' .env | xargs)
    tmpf=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/byGentleman/Softs/main/aztec/register-validator.sh > "$tmpf"
    bash "$tmpf"
    rm -f "$tmpf"
    say_thanks
    ;;
  5)
    echo -e "${RED}Полное удаление ноды...${NC}"
    docker stop aztec-sequencer
    docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Нода удалена.${NC}"
    say_thanks
    ;;
  *)
    echo -e "${RED}Неверный выбор. Выход.${NC}"
    exit 1
    ;;
esac
