#!/bin/bash

# Обновляем систему
echo "Обновляем систему перед настройкой..."
sudo apt update -y && sudo apt upgrade -y

# Проверка наличия необходимых утилит, установка если отсутствуют
if ! command -v figlet &> /dev/null; then
    echo "figlet не найден. Устанавливаем..."
    sudo apt update && sudo apt install -y figlet
fi

if ! command -v whiptail &> /dev/null; then
    echo "whiptail не найден. Устанавливаем..."
    sudo apt update && sudo apt install -y whiptail
fi

# Определяем цвета
PINK="\e[35m"
NC="\e[0m"
GREEN="\e[32m"

# Вывод логотипа
echo -e "${PINK}$(figlet -w 150 -f standard \"Softs by Gentleman\")${NC}"
echo -e "${PINK}$(figlet -w 150 -f standard \"x WESNA\")${NC}"

echo "===================================================================================================================================="
echo "Добро пожаловать! Подпишитесь на наши Telegram-каналы для обновлений и поддержки:"
echo "Gentleman - https://t.me/GentleChron"
echo "Wesna - https://t.me/softs_by_wesna"
echo "===================================================================================================================================="

echo ""

# Анимация загрузки меню
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

# Функция установки ноды
install_node() {
    echo "Hello"
}

# Основное меню
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 15 50 2 \
    "1" "Установка ноды" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1) 
        install_node
        ;;
    *)
        echo -e "${GREEN}Выход из программы.${NC}"
        ;;
esac
