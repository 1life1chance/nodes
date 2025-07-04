#!/bin/bash

# Проверка и установка нужных утилит
for util in figlet whiptail curl docker iptables jq; do
  if ! command -v "$util" &>/dev/null; then
    echo "$util не найден. Устанавливаю..."
    sudo apt update && sudo apt install -y "$util"
  fi
done

# Цвета
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
PURPLE="\e[35m"
NC="\e[0m"

# Приветствие
echo -e "\n\n"
echo -e "${CYAN}$(figlet -w 150 -f standard \"Soft by The Gentleman\")${NC}"
echo "=========================================================================="
echo "             Добро пожаловать в мастер установки 0.87.9                   "
echo "=========================================================================="

echo -e "${YELLOW}Подписывайтесь на Telegram: https://t.me/GentleChron${NC}"
echo -e "${CYAN}Продолжение через 10 секунд...${NC}"
sleep 10

# Анимация
animate() {
  for i in {1..3}; do
    printf "\r${GREEN}Загрузка${NC}%s" "$(printf '.%.0s' $(seq 1 $i))"
    sleep 0.4
  done
  echo
}
animate

# Благодарность
give_ack() {
  echo
  echo -e "${CYAN}Спасибо! Подписывайтесь: https://t.me/GentleChron${NC}"
}

# Меню выбора
CHOICE=$(whiptail --title "Меню управления Aztec" \
  --menu "Выберите нужное действие:" 20 70 9 \
    "1" "Первичная установка и запуск" \
    "2" "Проверка лога событий" \
    "3" "Запрос текущего хеша" \
    "4" "Регистрация в сети" \
    "5" "Обновление ПО ноды" \
    "6" "Перезапуск контейнера" \
    "7" "Удаление всех данных" \
  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "${RED}Отмена. Выход.${NC}"
  exit 1
fi

case $CHOICE in
  1)
    echo -e "${GREEN}Установка зависимостей...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install -y iptables-persistent curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

    if ! command -v docker &> /dev/null; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER"
    fi

    if ! getent group docker > /dev/null; then
      sudo groupadd docker
    fi
    sudo usermod -aG docker "$USER"

    sudo systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    sudo iptables -I INPUT -p tcp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 40400 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"

    mkdir -p "$HOME/aztec-sequencer"
    cd "$HOME/aztec-sequencer"

    docker pull aztecprotocol/aztec:0.87.7

    read -p "Вставьте ваш URL RPC Sepolia: " RPC
    read -p "Вставьте ваш URL Beacon Sepolia: " CONSENSUS
    read -p "Вставьте приватный ключ от вашего кошелька (0x…): " PRIVATE_KEY
    read -p "Вставьте адрес вашего кошелька (0x…): " WALLET

    SERVER_IP=$(curl -s https://api.ipify.org)

    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC
L1_CONSENSUS_HOST_URLS=$CONSENSUS
VALIDATOR_PRIVATE_KEY=$PRIVATE_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET
GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef
EOF

    mkdir -p "$HOME/aztec-sequencer/data"

    docker run -d \
      --name aztec-sequencer \
      --network host \
      --entrypoint /bin/sh \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:0.87.7 \
      -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
    echo -e "${YELLOW}Команда для проверки логов:${NC}" 
    echo "docker logs --tail 100 -f aztec-sequencer"
    echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
    echo -e "${GREEN}Процесс завершён.${NC}"
    sleep 2
    docker logs --tail 100 -f aztec-sequencer
    ;;

  2)
    docker logs --tail 100 -f aztec-sequencer
    ;;

  3)
    echo -e "${GREEN}Запрос хеша...${NC}"
    cd "$HOME/aztec-sequencer"
    TIP=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' http://localhost:8080)
    BLK=$(echo "$TIP" | jq -r '.result.proven.number')
    PROOF=$(curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[${BLK},${BLK}],\"id\":1}" http://localhost:8080 | jq -r '.result')
    echo -e "${GREEN}Block: ${NC}$BLK"
    echo -e "${GREEN}Proof:${NC} $PROOF"
    give_ack
    ;;

  4)
    echo -e "${GREEN}Запускаю регистрацию валидатора...${NC}"
    cd "$HOME/aztec-sequencer"
    [ -f .env ] && export $(grep -v '^#' .env | xargs)
    tmpnv=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/TheGentIeman/Nodes/refs/heads/main/NewValidator.sh > "$tmpnv"
    chmod +x "$tmpnv"
    bash "$tmpnv"
    rm -f "$tmpnv"
    give_ack
    ;;

  5)
    echo -e "${BLUE}Обновление ноды Aztec...${NC}"
    docker pull aztecprotocol/aztec:0.87.9
    docker stop aztec-sequencer
    docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer/data/*"
    mkdir -p "$HOME/aztec-sequencer/data"
    docker run -d \
      --name aztec-sequencer \
      --network host \
      --entrypoint /bin/sh \
      --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data \
      -e LOG_LEVEL=debug \
      -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:0.87.9 \
      -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    echo -e "${GREEN}Обновление завершено.${NC}"
    docker logs --tail 100 -f aztec-sequencer
    ;;

  6)
    docker restart aztec-sequencer
    docker logs --tail 100 -f aztec-sequencer
    ;;

  7)
    echo -e "${BLUE}Удаление ноды Aztec...${NC}"
    docker stop aztec-sequencer
    docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Нода удалена.${NC}"
    ;;

  *)
    echo -e "${RED}Неверный выбор. Пожалуйста, выберите пункт из меню.${NC}"
    ;;
esac
