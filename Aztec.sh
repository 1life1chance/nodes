#!/bin/bash

# Проверка и установка нужных утилит
for tool in figlet whiptail curl docker iptables jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Утилита '$tool' не найдена. Устанавливаю..."
    sudo apt update && sudo apt install -y "$tool"
  fi
done

# Цветовые константы
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
NC="\e[0m"

# Приветствие
clear
echo -e "${CYAN}$(figlet -w 120 -f standard \"Soft by The Gentleman\")${NC}"
echo "================================================================"
echo "      Добро пожаловать в мастер управления Aztec-нодой       "
echo "================================================================"

# Напоминание о канале
echo
echo -e "${YELLOW}Не забудьте подписаться: https://t.me/GentleChron${NC}"
echo -e "${CYAN}Дальнейшие действия начнутся через 10 секунд...${NC}"
sleep 10

# Простая анимация
print_loading() {
  for dot in . . .; do
    printf "\r${GREEN}Загружаю скрипт%s${NC}" "$dot"
    sleep 0.5
  done
  echo
}
print_loading

# Главное меню
choice=$(whiptail --title "Aztec Node Control" \
  --menu "Выберите пункт:" 15 60 5 \
    1 "Установить ноду" \
    2 "Показать логи" \
    3 "Проверить хеш" \
    4 "Добавить валидатора" \
    5 "Удалить ноду" \
  3>&1 1>&2 2>&3)

# Функция вывода благодарности
show_ack() {
  echo
echo -e "${CYAN}Спасибо за выбор! Подписывайтесь на канал: https://t.me/GentleChron${NC}"
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

    mkdir -p "$HOME/aztec-sequencer"
    cd "$HOME/aztec-sequencer" || exit 1
    echo -e "${YELLOW}Получаю последнюю сборку Aztec...${NC}"
    latest=$(curl -s "https://registry.hub.docker.com/v2/repositories/aztecprotocol/aztec/tags?page_size=100" \
      | jq -r '.results[].name' | grep -E '^0\..*-alpha-testnet\.[0-9]+' | sort -V | tail -1)
    [ -z "$latest" ] && latest="alpha-testnet"
    echo -e "${GREEN}Используем тег: $latest${NC}"
    docker pull aztecprotocol/aztec:"$latest"

    read -p "RPC Sepolia URL: " RPC_URL
    read -p "Beacon Sepolia URL: " CONS_URL
    read -p "Ваш приватный ключ: " PRIV_KEY
    read -p "Адрес кошелька: " WALLET_ADDR

    server_ip=$(curl -s https://api.ipify.org)
    cat > .env <<EOF
ETHEREUM_HOSTS=$RPC_URL
L1_CONSENSUS_HOST_URLS=$CONS_URL
VALIDATOR_PRIVATE_KEY=$PRIV_KEY
P2P_IP=$server_ip
WALLET=$WALLET_ADDR
EOF

    echo -e "${GREEN}Запускаю контейнер с нодой...${NC}"
    docker run -d --name aztec-sequencer --network host --env-file "$HOME/aztec-sequencer/.env" \
      -e DATA_DIRECTORY=/data -e LOG_LEVEL=debug -v "$HOME/aztec-sequencer/data":/data \
      aztecprotocol/aztec:"$latest" \
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'

    show_ack
    ;;
  2)
    echo -e "${GREEN}Показываю логи Aztec...${NC}"
    docker logs --tail 100 -f aztec-sequencer
    show_ack
    ;;
  3)
    echo -e "${GREEN}Запрос хеша блока...${NC}"
    cd "$HOME/aztec-sequencer" || exit 1
    tip=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' http://localhost:8080)
    blk=$(echo "$tip" | jq -r '.result.proven.number')
    proof=$(curl -s -X POST -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[${blk},${blk}],\"id\":1}" http://localhost:8080 | jq -r '.result')
    echo -e "${GREEN}Номер блока:${NC} $blk"
    echo -e "${GREEN}Proof:${NC} $proof"
    show_ack
    ;;
  4)
    echo -e "${GREEN}Запускаю подключение валидатора...${NC}"
    cd "$HOME/aztec-sequencer" || exit 1
    source .env

    # выполняем команду и сохраняем вывод
    result=$(docker exec -i aztec-sequencer \
      sh -c 'node /usr/src/yarn-project/aztec/dest/bin/index.js add-l1-validator \
        --l1-rpc-urls "${ETHEREUM_HOSTS}" \
        --private-key "${VALIDATOR_PRIVATE_KEY}" \
        --attester "${WALLET}" \
        --proposer-eoa "${WALLET}" \
        --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
        --l1-chain-id 11155111' 2>&1) || true

    # проверяем квоту
        # обработка ситуации с заполненной квотой
    if echo "$result" | grep -q 'ValidatorQuotaFilledUntil'; then
      ts=$(echo "$result" \
        | grep -oP '(?<=\()[0-9]+(?=\))' \
        | head -1)
      now=$(date +%s)
      wait=$(( (ts - now) / 60 ))
      echo -e "${YELLOW}Квота заполнена. Повторите попытку через ${wait} минут.${NC}"
    # остальные ошибки
    elif echo "$result" | grep -q 'Error:'; then "$result" | grep -q 'Error:'; then
      err=$(echo "$result" | grep -m1 'Error:')
      echo -e "${RED}Ошибка при подключении: $err${NC}"
    else
      echo -e "${GREEN}Валидатор подключён успешно!${NC}"
    fi
    show_ack
    ;;
  5)
    echo -e "${RED}Удаляю все данные ноды...${NC}"
    docker stop aztec-sequencer && docker rm aztec-sequencer
    rm -rf "$HOME/aztec-sequencer"
    echo -e "${GREEN}Очистка завершена.${NC}"
    show_ack
    ;;
  *)
    echo -e "${RED}Неверный выбор. Завершаю работу.${NC}"
    exit 1
    ;;
esac
