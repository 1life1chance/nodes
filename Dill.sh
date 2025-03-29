#!/bin/bash

# Проверка наличия необходимых утилит, установка если отсутствует
if ! command -v figlet &> /dev/null; then
    echo "figlet не найден. Устанавливаем..."
    sudo apt update && sudo apt install -y figlet
fi

if ! command -v whiptail &> /dev/null; then
    echo "whiptail не найден. Устанавливаем..."
    sudo apt update && sudo apt install -y whiptail
fi

# Проверка и установка Docker
if ! command -v docker &> /dev/null; then
    echo -e "\e[35mDocker не найден. Устанавливаем Docker...\e[0m"
    curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

    # Устанавливаем путь к docker, если скрипт запущен как root
    export PATH=$PATH:/usr/bin

    echo -e "\e[32mDocker установлен. Продолжаем выполнение...\e[0m"
    sleep 2
fi

# Проверка и установка Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "\e[35mDocker Compose не найден. Устанавливаем...\e[0m"
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# Определяем цвета
GREEN="\e[32m"
PINK="\e[35m"
RED="\e[31m"
NC="\e[0m"

# Вывод приветственного текста
echo -e "${PINK}$(figlet -w 150 -f standard \"Soft by The Gentleman\")${NC}"
echo "================================================================="
echo "Добро пожаловать! Выберите действие из меню ниже:"
echo "================================================================="

# Функция анимации
animate_loading() {
    for ((i = 1; i <= 5; i++)); do
        printf "\r${GREEN}Подгружаем меню${NC}."
        sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}.."
        sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}..."
        sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}"
        sleep 0.3
    done
    echo ""
}

animate_loading

# Вывод меню
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 20 80 7 \
    "1" "Установить ноду" \
    "2" "Проверить работу ноды" \
    "3" "Показать публичный ключ" \
    "4" "Остановить ноду" \
    "5" "Перезапустить ноду" \
    "6" "Добавить ещё одного валидатора на этот сервер" \
    "7" "Установить валидатор на отдельный сервер" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        echo -e "${GREEN}Установка ноды...${NC}"
        sudo apt update && sudo apt install -y curl
        curl -sO https://raw.githubusercontent.com/DillLabs/launch-dill-node/main/dill.sh && chmod +x dill.sh && ./dill.sh
        ;;

    2)
        echo -e "${GREEN}Проверка работы ноды...${NC}"
        cd ~/dill && ./health_check.sh -v
        ;;

    3)
        echo -e "${GREEN}Ваш публичный ключ:${NC}"
        cd ~/dill && ./show_pubkey.sh
        ;;

    4)
        echo -e "${GREEN}Остановка ноды...${NC}"
        cd ~/dill && ./stop_dill_node.sh
        ;;

    5)
        echo -e "${GREEN}Перезапуск ноды...${NC}"
        cd ~/dill && ./start_dill_node.sh
        ;;

    6)
        echo -e "${GREEN}Добавление нового валидатора на текущий сервер...${NC}"

        echo -e "${GREEN}Останавливаем текущую ноду для безопасного добавления валидатора...${NC}"
        cd ~/dill && ./stop_dill_node.sh || echo "Нода уже остановлена или возникла ошибка"
        sleep 2

        OLD_VALIDATOR=$(setsid docker compose run --rm dill dill keys list | grep 'name:' | head -n 1 | awk '{print $2}')
        echo -e "${GREEN}Текущий основной валидатор определен автоматически: ${PINK}$OLD_VALIDATOR${NC}"

        read -p "Введите имя нового валидатора (любое удобное имя, не влияет на работу ноды): " NEW_VALIDATOR
        read -p "Введите сумму токенов (DILL, целое число). Например, для Light-ноды нужно минимум 3600 DILL, для Full-ноды минимум 360000 DILL: " TOKEN_AMOUNT

        TOKEN_AMOUNT_UDILL=$(($TOKEN_AMOUNT * 1000000))
        TOKEN_AMOUNT_STR="${TOKEN_AMOUNT_UDILL}udill"

        setsid docker compose run --rm dill dill keys add $NEW_VALIDATOR

        echo -e "${GREEN}Пополняем баланс нового валидатора...${NC}"
        NEW_VALIDATOR_ADDRESS=$(setsid docker compose run --rm dill dill keys show $NEW_VALIDATOR -a)

        setsid docker compose run --rm dill dill tx bank send $OLD_VALIDATOR $NEW_VALIDATOR_ADDRESS $TOKEN_AMOUNT_STR --fees=2000udill --chain-id=dillchain --node https://rpc.dillchain.io:443

        echo -e "${GREEN}Создаем нового валидатора...${NC}"
        setsid docker compose run --rm dill dill tx staking create-validator \
          --amount=$TOKEN_AMOUNT_STR \
          --pubkey=$(setsid docker compose run --rm dill dill tendermint show-validator) \
          --moniker="$NEW_VALIDATOR" \
          --chain-id=dillchain \
          --commission-rate="0.10" \
          --commission-max-rate="0.20" \
          --commission-max-change-rate="0.01" \
          --min-self-delegation="1" \
          --gas="auto" \
          --gas-adjustment="1.5" \
          --fees=2000udill \
          --from=$NEW_VALIDATOR \
          --node=https://rpc.dillchain.io:443

        echo -e "${GREEN}Перезапускаем ноду...${NC}"
        ./start_dill_node.sh
        ;;

    7)
        echo -e "${GREEN}Установка валидатора на отдельный сервер...${NC}"

        read -p "Введите имя нового валидатора (любое удобное имя, не влияет на работу ноды): " NEW_VALIDATOR
        read -p "Введите сумму токенов для стейкинга (например, для Light-ноды 3600 DILL, для Full-ноды 360000 DILL): " TOKEN_AMOUNT

        TOKEN_AMOUNT_UDILL=$(($TOKEN_AMOUNT * 1000000))
        TOKEN_AMOUNT_STR="${TOKEN_AMOUNT_UDILL}udill"

        echo -e "${GREEN}Установка ПО Diil Node...${NC}"
        sudo apt update && sudo apt install -y curl
        curl -sO https://raw.githubusercontent.com/DillLabs/launch-dill-node/main/dill.sh && chmod +x dill.sh && ./dill.sh

        cd ~/dill

        setsid docker compose run --rm dill dill keys add $NEW_VALIDATOR
        NEW_VALIDATOR_ADDRESS=$(setsid docker compose run --rm dill dill keys show $NEW_VALIDATOR -a)

        echo -e "${PINK}ВАЖНО:${NC} Переведите ${PINK}$TOKEN_AMOUNT DILL${NC} (адрес: ${GREEN}$NEW_VALIDATOR_ADDRESS${NC}) с текущей (старой) ноды и нажмите Enter после успешного перевода."
        read -p "Нажмите Enter после перевода токенов:"

        setsid docker compose run --rm dill dill tx staking create-validator \
          --amount=$TOKEN_AMOUNT_STR \
          --pubkey=$(setsid docker compose run --rm dill dill tendermint show-validator) \
          --moniker="$NEW_VALIDATOR" \
          --chain-id=dillchain \
          --commission-rate="0.10" \
          --commission-max-rate="0.20" \
          --commission-max-change-rate="0.01" \
          --min-self-delegation="1" \
          --gas="auto" \
          --gas-adjustment="1.5" \
          --fees=2000udill \
          --from=$NEW_VALIDATOR \
          --node=https://rpc.dillchain.io:443
        ;;

    *)
        echo -e "${RED}Неверный выбор. Завершение программы.${NC}"
        ;;
esac
