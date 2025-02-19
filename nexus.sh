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
    echo -e "${GREEN}Настройка окружения...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

    echo -e "${GREEN}Удаление needrestart...${NC}"
    sudo apt-get purge -y needrestart || echo "needrestart не установлен, пропускаем..."

    echo -e "${GREEN}Очистка старых ядер и зависимостей...${NC}"
    sudo apt-get autoremove --purge -y

    echo -e "${GREEN}Удаление старых версий Docker...${NC}"
    packages=(
        docker docker.io docker-ce docker-ce-cli containerd containerd.io runc
        docker-doc docker-compose docker-compose-v2 podman-docker
    )
    for pkg in "${packages[@]}"; do
        sudo apt-get remove --purge -y "$pkg" || echo "$pkg не найден, пропускаем..."
    done
    sudo apt-get autoremove -y

    echo -e "${GREEN}Обновление системы...${NC}"
    sudo apt-get update -y && sudo apt-get upgrade -y

    echo -e "${GREEN}Установка необходимых пакетов...${NC}"
    sudo apt-get install -y \
        ca-certificates curl gnupg lsb-release \
        apt-utils dialog build-essential git jq lz4 unzip make gcc ncdu \
        cmake clang pkg-config libssl-dev libzmq3-dev libczmq-dev python3-pip \
        protobuf-compiler dos2unix screen

    echo -e "${GREEN}Настройка Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl is-active --quiet docker && echo "Docker активен" || echo "Docker не активен"

    echo -e "${GREEN}Установка Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    rustup update

    echo -e "${GREEN}Запуск ноды Nexus...${NC}"
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
