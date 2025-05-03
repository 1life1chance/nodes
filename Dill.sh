#!/bin/bash

# Проверка и установка нужных утилит
for util in figlet whiptail curl docker iptables jq; do
  if ! command -v "$util" &>/dev/null; then
    echo "$util не найден. Устанавлию..."
    sudo apt update && sudo apt install -y "$util"
  fi
done

# Цветовые константы
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
NC="\e[0m"

clear
# Приветствие
echo -e "${CYAN}$(figlet -w 150 -f standard \"Soft by The Gentleman\")${NC}"
echo "================================================================"
echo "      Добро пожаловать в мастер установки ноды Aztec от Джентльмена       "
echo "================================================================"

echo -e "${YELLOW}Подписывайтесь на Telegram: https://t.me/GentleChron${NC}"
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

# Главное меню через whiptail
CHOICE=$(whiptail --title "Aztec Node Control" \
  --menu "Выберите действие:" 15 60 5 \
    "1" "Установить ноду" \
    "2" "Показать логи" \
    "3" "Проверить хеш" \
    "4" "Зарегистрировать валидатора" \
    "5" "Удалить ноду" \
  3>&1 1>&2 2>&3)

# Если пользователь нажал Esc или Cancel
if [ $? -ne 0 ]; then
  echo -e "${RED}Отмена. Выход.${NC}"
  exit 1
fi

# Благодарность
give_ack() {
  echo
  echo -e "${CYAN}Спасибо! Подписывайтесь: https://t.me/GentleChron${NC}"
}

case "$CHOICE" in

  1)
    echo -e "${GREEN}Готовлю окружение...${NC}"
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

    mkdir -p "$HOME/aztec-sequencer" && cd "$HOME/aztec-sequencer"
    echo -e "${YELLOW}Получаем последнюю сборку Aztec...${NC}"
    LATEST=$(curl -s "https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=100" \
      | jq -r '.results[].name' | grep -E '^0\..*-alpha-testnet\.[0-9]+' | sort -V | tail -1)
    [ -z "$LATEST" ] && LATEST="alpha-testnet"
    echo -e "${GREEN}Используем тег: $LATEST${NC}"
    docker pull aztecprotocol/aztec:"$LATEST"

    read -p "RPC Sepolia URL: " RPC_URL
    read -p "Beacon Sepolia URL: " CONS_URL
    read -p "Ваш приватный ключ: " PRIV_KEY
    read -p "Адрес кошелька: " WALLET_ADDR

    SERVER_IP=$(curl -s https://api.ipify.org)
    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC_URL
L1_CONSENSUS_HOST_URLS=$CONS_URL
VALIDATOR_PRIVATE_KEY=$PRIV_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET_ADDR
EOF

    echo -e "${GREEN}Запускаем контейнер...${NC}"
    docker run -d --name aztec-sequencer --network host --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data -e LOG_LEVEL=debug -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:"$LATEST" \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    give_ack
    ;;

  2)
    echo -e "${GREEN}Показываю логи...${NC}"
    docker logs --tail 100 -f aztec-sequencer | grep -v "Rollup__Invalid" | grep -v "type: 'error'"
    give_ack
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
    echo -e "${GREEN}Запускаю процедуру регистрации валидатора...${NC}"
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
    echo -e "${RED}Удаляю ноду...${NC}"
    docker stop aztec-sequencer && docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Нода удалена.${NC}"
    give_ack
    ;;

  *)
    echo -e "${RED}Неверный выбор. Выход.${NC}"
    exit 1
    ;;
esac
