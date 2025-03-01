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

# Определяем цвета для удобства
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

# Вывод приветственного текста с помощью figlet
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by The Gentleman")${NC}"


echo "===================================================================================================================================="
echo "Добро пожаловать! Начинаем установку необходимых библиотек, пока подпишись на мой Telegram-канал для обновлений и поддержки: "
echo ""
echo "The Gentleman - https://t.me/GentleChron"
echo "===================================================================================================================================="

echo ""

# Определение функции анимации
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

# Вызов функции анимации
animate_loading
echo ""

# Вывод меню действий
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 15 50 4 \
    "1" "Установить ноду" \
    "2" "Проверить статус ноды" \
    "3" "Удалить ноду" \
    "4" "Покинуть меню" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        echo -e "${BLUE}Устанавливаем ноду...${NC}"

        sudo apt update && sudo apt upgrade -y
        rm -f ~/install.sh ~/update.sh ~/start.sh
        
        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/install.sh
        source ./install.sh

        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/update.sh
        source ./update.sh

        cd ~/multipleforlinux

        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/start.sh
        source ./start.sh

        echo -e "${YELLOW}Введите ваш Account ID (unique identification code):${NC}"
        read IDENTIFIER
        echo -e "${YELLOW}Придумайте пароль:${NC}"
        read PIN

        multiple-cli bind --bandwidth-download 100 --identifier $IDENTIFIER --pin $PIN --storage 200 --bandwidth-upload 100

        echo -e "${PINK}-----------------------------------------------------------${NC}"
        echo -e "${YELLOW}Команда для проверки статуса ноды:${NC}"
        echo "cd ~/multipleforlinux && ./multiple-cli status"
        echo -e "${PINK}-----------------------------------------------------------${NC}"
        echo -e "${GREEN}Установка завершена!${NC}"
        sleep 2
        cd ~/multipleforlinux && ./multiple-cli status
        ;;

    2)
        echo -e "${BLUE}Проверяем статус...${NC}"
        cd ~/multipleforlinux && ./multiple-cli status
        ;;

    3)
        echo -e "${BLUE}Удаление ноды...${NC}"
        pkill -f multiple-node
        sudo rm -rf ~/multipleforlinux
        echo -e "${GREEN}Нода успешно удалена!${NC}"
        ;;
    
    4)
        echo -e "${CYAN}Выход из программы.${NC}"
        exit 0
        ;;
    
    *)
        echo -e "${RED}Неверный выбор. Завершение программы.${NC}"
        ;;
esac
