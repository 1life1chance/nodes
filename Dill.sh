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
    --menu "Выберите действие:" 15 60 5 \
    "1" "Установить ноду" \
    "2" "Проверить работу ноды" \
    "3" "Показать публичный ключ" \
    "4" "Остановить ноду" \
    "5" "Перезапустить ноду" \
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

    *)
        echo -e "${RED}Неверный выбор. Завершение программы.${NC}"
        ;;
esac
