#!/bin/bash

# ======================
# Nexus Node Installer & Updater
# ======================
# Автор: The Gentleman
# Обновлено: 2025‑06‑28
# ----------------------

###############################################################################
# Цвета для вывода                                                              
###############################################################################
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

###############################################################################
# Функции установки зависимостей                                               
###############################################################################
install_dependencies() {
    echo -e "${GREEN}Устанавливаем необходимые пакеты...${NC}"
    sudo apt update && sudo apt install -y \
        curl iptables build-essential git wget lz4 jq make gcc nano \
        automake autoconf tmux htop nvme-cli pkg-config libssl-dev \
        libleveldb-dev tar clang bsdmainutils ncdu unzip screen \
        protobuf-compiler ca-certificates libzmq3-dev libczmq-dev \
        python3-pip dos2unix libcurl4-openssl-dev figlet whiptail
}

install_rust() {
    echo -e "${GREEN}Устанавливаем Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
    rustup update
}

###############################################################################
# Функция установки новой ноды Nexus                                           
###############################################################################
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
    local packages=(docker docker.io docker-ce docker-ce-cli containerd containerd.io runc \
                    docker-doc docker-compose docker-compose-v2 podman-docker)
    for pkg in "${packages[@]}"; do
        sudo apt-get remove --purge -y "$pkg" || echo "$pkg не найден, пропускаем..."
    done
    sudo apt-get autoremove -y

    echo -e "${GREEN}Обновление системы...${NC}"
    sudo apt-get update -y && sudo apt-get upgrade -y

    echo -e "${GREEN}Установка необходимых пакетов...${NC}"
    sudo apt-get install -y \
        ca-certificates curl gnupg lsb-release apt-utils dialog build-essential \
        git jq lz4 unzip make gcc ncdu cmake clang pkg-config libssl-dev \
        libzmq3-dev libczmq-dev python3-pip protobuf-compiler dos2unix screen

    echo -e "${GREEN}Настройка Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \\
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl is-active --quiet docker && echo "Docker активен" || echo "Docker не активен"

    # Rust
    install_rust

    # Nexus install
    echo -e "${GREEN}Запуск ноды Nexus...${NC}"
    screen -dmS nexus_node bash -c 'curl https://cli.nexus.xyz/ | sh; exec bash'
    sleep 5
    screen -r nexus_node
}

###############################################################################
# Функция обновления существующей ноды Nexus                                   
###############################################################################
update_node() {
    # Файл, где будем хранить ID ноды между запусками
    local NODE_ID_FILE="$HOME/.nexus_node_id"
    local DEFAULT_NODE_ID=""
    if [[ -f "$NODE_ID_FILE" ]]; then
        DEFAULT_NODE_ID=$(cat "$NODE_ID_FILE")
    fi

    # Запрос ID у пользователя
    NODE_ID=$(whiptail --inputbox "Введите ID вашей ноды:" 8 60 "$DEFAULT_NODE_ID" \
              --title "Обновление ноды" 3>&1 1>&2 2>&3)

    # Если пользователь отменил ввод
    if [[ $? -ne 0 || -z "$NODE_ID" ]]; then
        echo -e "${RED}ID ноды не введён. Возврат в меню.${NC}"
        return
    fi

    # Сохраняем ID для будущих запусков
    echo "$NODE_ID" > "$NODE_ID_FILE"

    # Обновление и перезапуск контейнера
    echo -e "${GREEN}Обновляем Nexus CLI до последней версии...${NC}"
    docker pull nexusxyz/nexus-cli:latest

    echo -e "${GREEN}Останавливаем старый контейнер (если есть)...${NC}"
    docker rm -f nexus &>/dev/null || true

    echo -e "${GREEN}Запуск новой версии с ID: $NODE_ID...${NC}"
    docker run -d --restart unless-stopped --name nexus nexusxyz/nexus-cli:latest start --node-id "$NODE_ID"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Нода успешно обновлена и запущена!${NC}"
    else
        echo -e "${RED}При запуске ноды произошла ошибка.${NC}"
    fi
}

###############################################################################
# Анимация загрузки меню                                                        
###############################################################################
animate_loading() {
    for ((i = 1; i <= 5; i++)); do
        printf "\r${GREEN}Подгружаем меню${NC}.";  sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}.."; sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}..."; sleep 0.3
        printf "\r${GREEN}Подгружаем меню${NC}   "; sleep 0.3
    done
    echo ""
}

###############################################################################
# Главный экран                                                                 
###############################################################################
clear
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by The Gentleman")${NC}"

cat <<EOL
====================================================================================================================================
Добро пожаловать! Начинаем установку необходимых библиотек. Пока подпишись на мой Telegram‑канал для обновлений и поддержки:

The Gentleman – https://t.me/GentleChron
====================================================================================================================================
EOL

animate_loading

###############################################################################
# Главное меню                                                                 
###############################################################################
while true; do
    CHOICE=$(whiptail --title "Меню действий" \
        --menu "Выберите действие:" 15 60 9 \
        "1" "Установить ноду" \
        "2" "Обновить ноду" \
        "3" "Выход" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            install_node
            ;;
        2)
            update_node
            ;;
        3)
            echo -e "${CYAN}Выход из программы.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор. Попробуйте ещё раз.${NC}"
            ;;
    esac

done
