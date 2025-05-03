#!/bin/bash

# Проверка и установка нужных утилит
for tool in figlet whiptail curl docker iptables jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Утилита '$tool' не найдена. Устанавливаю..."
    sudo apt update && sudo apt install -y "$tool"
  fi
done

# Цвета
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
NC="\e[0m"

clear
# Приветствие
echo -e "${CYAN}$(figlet -w 120 -f standard \"Soft by The Gentleman\")${NC}"
echo "================================================================"
echo "      Добро пожаловать в мастер управления Aztec-нодой       "
echo "================================================================"

echo -e "${YELLOW}Не забудьте подписаться: https://t.me/GentleChron${NC}"
echo -e "${CYAN}Дальнейшие действия начнутся через 10 секунд...${NC}"
sleep 10

# Анимация загрузки
print_loading() {
  for dot in . . .; do
    printf "\r${GREEN}Загружаю скрипт%s${NC}" "$dot"
    sleep 0.5
  done
  echo
}
print_loading

# Главное меню с whiptail
choice=$(whiptail --title "Aztec Node Control" \
  --menu "Выберите действие:" 16 60 5 \
    "1" "Установить ноду" \
    "2" "Показать логи" \
    "3" "Проверить хеш" \
    "4" "Добавить валидатора" \
    "5" "Удалить ноду" \
  3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
  echo -e "${RED}Действие отменено пользователем.${NC}"
  exit 1
fi

give_ack() {
  echo
echo -e "${CYAN}Спасибо за выбор! Подписывайтесь: https://t.me/GentleChron${NC}"
}

case "$choice" in
  1)
    echo -e "${GREEN}Готовлю окружение и скачиваю компоненты...${NC}"
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
    echo -e "${YELLOW}Получаю последнюю сборку Aztec...${NC}"
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

    echo -e "${GREEN}Запускаю контейнер...${NC}"
    docker run -d --name aztec-sequencer --network host --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data -e LOG_LEVEL=debug -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:"$LATEST" \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    give_ack
    ;;
  2)
    echo -e "${GREEN}Показываю логи...${NC}"
    docker logs --tail 100 -f aztec-sequencer
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
    echo -e "${GREEN}Запускаю подключение валидатора...${NC}"
    cd "$HOME/aztec-sequencer"
    source .env
    RAW=$(docker exec -i aztec-sequencer \
      sh -c 'node /usr/src/yarn-project/aztec/dest/bin/index.js add-l1-validator \
        --l1-rpc-urls "${ETHEREUM_HOSTS}" \
        --private-key "${VALIDATOR_PRIVATE_KEY}" \
        --attester "${WALLET}" \
        --proposer-eoa "${WALLET}" \
        --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
        --l1-chain-id 11155111' 2>&1) || true
    if echo "$RAW" | grep -q 'ValidatorQuotaFilledUntil'; then
      echo -e "${YELLOW}Регистрация временно недоступна, попробуйте позже.${NC}"
    elif echo "$RAW" | grep -q 'Error:'; then
      ERR=$(echo "$RAW" | grep -m1 'Error:')
      echo -e "${RED}Ошибка подключения: $ERR${NC}"
    else
      echo -e "${GREEN}Валидатор подключён успешно!${NC}"
    fi
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
    echo -e "${RED}Неверный выбор.${NC}"
    exit 1
    ;;
esac
