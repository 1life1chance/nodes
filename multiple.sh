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
echo "Добро пожаловать! Начинаем установку необходимых библиотек, пока подпишись на наши Telegram-канал для обновлений и поддержки: "
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
        printf "\r${GREEN}Подгружаем меню${NC} "
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

        # Проверяем существование папки multipleforlinux
        if [ ! -d "$HOME/multipleforlinux" ]; then
            echo -e "${RED}Ошибка: директория multipleforlinux не найдена!${NC}"
            exit 1
        fi
        cd ~/multipleforlinux || exit 1

        # Выдача прав на выполнение
        chmod +x multiple-cli multiple-node start.sh

        # Перезапуск ноды
        echo -e "${BLUE}Запускаем multiple-node...${NC}"
        ./start.sh

        # Проверяем, работает ли процесс
        sleep 5
        if ! pgrep -f multiple-node > /dev/null; then
            echo -e "${RED}Ошибка: multiple-node не запустился!${NC}"
            exit 1
        fi

        # Ввод Account ID и PIN
        echo -e "${YELLOW}Введите ваш Account ID:${NC}"
        read -r IDENTIFIER
        echo -e "${YELLOW}Придумайте пароль (PIN):${NC}"
        read -r PIN
        
        # Проверяем, существует ли multiple-cli перед привязкой
        if [ ! -f "./multiple-cli" ]; then
            echo -e "${RED}Ошибка: multiple-cli не найден!${NC}"
            exit 1
        fi

        # Привязка аккаунта
        echo -e "${BLUE}Привязываем аккаунт...${NC}"
        ./multiple-cli bind --identifier "$IDENTIFIER" --pin "$PIN" --storage 200 --bandwidth-upload 100

        # Проверяем, успешно ли привязана нода
        sleep 5
        BIND_STATUS=$(./multiple-cli status | grep -i "bound")
        if [[ -z "$BIND_STATUS" ]]; then
            echo -e "${RED}Ошибка: Нода не привязана! Попробуйте повторно.${NC}"
            exit 1
        fi

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
        if [ -f "$HOME/multipleforlinux/multiple-cli" ]; then
            cd ~/multipleforlinux && ./multiple-cli status
        else
            echo -e "${RED}Ошибка: multiple-cli не найден!${NC}"
        fi
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
