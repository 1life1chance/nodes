#!/bin/bash

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

# Определяем цвета для удобства
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

install_dependencies() {
    echo -e "${GREEN}Устанавливаем необходимые пакеты...${NC}"
    sudo apt update && sudo apt install -y \
        curl \
        iptables \
        build-essential \
        git \
        wget \
        lz4 \
        jq \
        make \
        gcc \
        nano \
        automake \
        autoconf \
        tmux \
        htop \
        nvme-cli \
        pkg-config \
        libssl-dev \
        libleveldb-dev \
        tar \
        clang \
        bsdmainutils \
        ncdu \
        unzip \
        screen \
        protobuf-compiler \
        ca-certificates \
        libzmq3-dev \
        libczmq-dev \
        python3-pip \
        dos2unix \
        libcurl4-openssl-dev \
        figlet \
        whiptail
}

install_rust() {
    echo -e "${GREEN}Устанавливаем Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    rustup update
}

install_node() {
    install_dependencies
    install_rust
    screen -dmS nexus_node bash -c 'curl https://cli.nexus.xyz/ | sh; exec bash'
    screen -r nexus_node
}

# Вывод приветственного текста с помощью figlet
echo -e "${PINK}$(figlet -w 150 -f standard \"Softs by Gentleman\")${NC}"
echo -e "${PINK}$(figlet -w 150 -f standard \"x WESNA\")${NC}"

echo "===================================================================================================================================="
echo "Добро пожаловать! Начинаем установку необходимых библиотек, пока подпишись на наши Telegram-каналы для обновлений и поддержки: "
echo ""
echo "Gentleman - https://t.me/GentleChron"
echo "Wesna - https://t.me/softs_by_wesna"
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

# Основное меню
CHOICE=$(whiptail --title "Меню действий" \
    --menu "Выберите действие:" 15 50 6 \
    "1" "Установка ноды" \
    "2" "Выход" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1) 
        install_node
        ;;
    2) 
        echo -e "${CYAN}Выход из программы.${NC}"
        ;;
    *)
        echo -e "${RED}Неверный выбор. Завершение программы.${NC}"
        ;;
esac
