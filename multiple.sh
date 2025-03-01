#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PINK='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

# Вывод приветственного текста с помощью figlet
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by TheGentleman")${NC}"

echo "===================================================================================================================================="
echo "Добро пожаловать! Начинаем установку необходимых библиотек, пока подпишись на наши Telegram-каналы для обновлений и поддержки: "
echo ""
echo "TheGentleman - https://t.me/GentleChron"
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

# Меню
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 15 50 4 \
    "1" "Установить" \
    "2" "Проверить статус" \
    "3" "Удалить ноду" \
    "4" "Выход" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        echo -e "${BLUE}Устанавливаем ноду...${NC}"

        # Обновление и установка зависимостей
        sudo apt update && sudo apt upgrade -y

        rm -f ~/install.sh ~/update.sh ~/start.sh
        
        # Скачиваем и устанавливаем клиент
        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/install.sh
        source ./install.sh

        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/update.sh
        source ./update.sh

        # Переход в папку клиента
        cd ~/multipleforlinux

        # Запуск ноды
        wget https://mdeck-download.s3.us-east-1.amazonaws.com/client/linux/start.sh
        source ./start.sh

        # Ввод Account ID и PIN
        echo -e "${YELLOW}Введите ваш Account ID:${NC}"
        read IDENTIFIER
        echo -e "${YELLOW}Придумайте пароль (PIN):${NC}"
        read PIN
        
        # Связываем ноду с сайтом
        ./multiple-cli bind --bandwidth-download 100 --identifier $IDENTIFIER --pin $PIN --storage 200 --bandwidth-upload 100

        # Заключительный вывод
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
