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
        printf "\r${GREEN}Подгружаем меню${NC}   "
        sleep 0.3
    done
    echo ""
}

animate_loading

# Вывод меню
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 17 60 6 \
    "1" "Установить ноду" \
    "2" "Проверить работу ноды" \
    "3" "Показать публичный ключ" \
    "4" "Остановить ноду" \
    "5" "Перезапустить ноду" \
    "6" "Обновить ноду" \
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
        echo -e "${GREEN}Обновление ноды...${NC}"
        cd ~/dill || { echo -e "${RED}Папка ~/dill не найдена.${NC}"; exit 1; }

        echo -e "${PINK}Скачиваем последнюю версию...${NC}"
        LATEST_VERSION=$(curl -s https://dill-release.s3.ap-southeast-1.amazonaws.com/version.txt)

        FILE_NAME="dill-${LATEST_VERSION}-linux-amd64.tar.gz"
        FILE_URL="https://dill-release.s3.ap-southeast-1.amazonaws.com/${LATEST_VERSION}/${FILE_NAME}"

        TEMP_DIR="tmp_update_$(date +%s)"
        mkdir "$TEMP_DIR" && cd "$TEMP_DIR"

        curl -O "$FILE_URL"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Ошибка загрузки архива. Проверь подключение к интернету.${NC}"
            cd .. && rm -rf "$TEMP_DIR"
            exit 1
        fi

        echo -e "${GREEN}Распаковываем...${NC}"
        tar -xzf "$FILE_NAME"
        cd dill

        echo -e "${GREEN}Останавливаем текущую ноду...${NC}"
        ~/dill/stop_dill_node.sh

        echo -e "${GREEN}Обновляем бинарники...${NC}"
        cp -f dill-node ~/dill/
        cp -f start_dill_node.sh ~/dill/
        cp -f stop_dill_node.sh ~/dill/
        chmod +x ~/dill/*.sh ~/dill/dill-node

        echo -e "${GREEN}Запускаем новую версию...${NC}"
        ~/dill/start_dill_node.sh

        echo -e "${GREEN}Обновление завершено. Установлена версия: ${LATEST_VERSION}${NC}"
        cd ../.. && rm -rf "$TEMP_DIR"
        ;;
    *)
        echo -e "${RED}Неверный выбор. Завершение программы.${NC}"
        ;;
esac
