#!/bin/bash

# Цвета
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
RED="\e[31m"
PINK="\e[35m"
NC="\e[0m"

INSTALL_DIR="/opt/popcache"
BIN_NAME="pop"
USER="popcache"

# Автоопределение архитектуры
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    BIN_URL="https://download.pipe.network/pop-x86_64"
elif [[ "$ARCH" == "aarch64" ]]; then
    BIN_URL="https://download.pipe.network/pop-arm64"
else
    echo -e "${RED}❌ Неизвестная архитектура: $ARCH. Установка прервана.${NC}"
    exit 1
fi

# Обновление и установка необходимых пакетов
echo -e "${YELLOW}Обновляем систему перед установкой...${NC}"
sudo apt update -y && sudo apt upgrade -y

if ! command -v figlet &> /dev/null; then
    sudo apt install -y figlet
fi
if ! command -v whiptail &> /dev/null; then
    sudo apt install -y whiptail
fi

# Приветствие
echo -e "${PINK}$(figlet -w 150 -f standard "Softs by The Gentleman")${NC}"
echo "===================================================================================================================================="
echo "Добро пожаловать! Начинаем установку необходимых библиотек, пока подпишись на мой Telegram-канал для обновлений и поддержки: "
echo ""
echo "The Gentleman - https://t.me/GentleChron"
echo "===================================================================================================================================="
echo ""

# Анимация
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

install_dependencies() {
    echo -e "${GREEN}Устанавливаем зависимости...${NC}"
    sudo apt install -y curl iptables build-essential git wget jq tmux htop pkg-config \
        libssl-dev libleveldb-dev tar clang ncdu unzip screen ca-certificates
}

install_node() {
    echo -e "${BLUE}Начинаем установку POP Cache Node...${NC}"
    install_dependencies

    INVITE=$(whiptail --inputbox "Введите ваш invite code:" 10 60 --title "Invite Code" 3>&1 1>&2 2>&3)
    SOLANA=$(whiptail --inputbox "Введите ваш публичный Solana-адрес для наград:" 10 60 --title "Solana Pubkey" 3>&1 1>&2 2>&3)

    echo -e "${GREEN}Создаем пользователя и директории...${NC}"
    sudo useradd -m -s /bin/bash $USER || true
    sudo usermod -aG sudo $USER || true
    sudo mkdir -p $INSTALL_DIR/cache $INSTALL_DIR/logs
    sudo chown -R $USER:$USER $INSTALL_DIR

    echo -e "${GREEN}Скачиваем бинарник ($ARCH)...${NC}"
    sudo wget -O $INSTALL_DIR/$BIN_NAME $BIN_URL
    sudo chmod +x $INSTALL_DIR/$BIN_NAME

    echo -e "${GREEN}Настраиваем системные параметры...${NC}"
    cat <<EOF | sudo tee /etc/sysctl.d/99-popcache.conf
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOF
    sudo sysctl -p /etc/sysctl.d/99-popcache.conf

    cat <<EOF | sudo tee /etc/security/limits.d/popcache.conf
*    hard nofile 65535
*    soft nofile 65535
EOF

    # config.json
    cat <<EOF | sudo tee $INSTALL_DIR/config.json
{
  "pop_name": "gentle-pop",
  "pop_location": "Earth, Internet",
  "invite_code": "$INVITE",
  "server": {
    "host": "0.0.0.0",
    "port": 443,
    "http_port": 80,
    "workers": 0
  },
  "cache_config": {
    "memory_cache_size_mb": 8192,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": 100,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "gentleman-node",
    "name": "Gentleman",
    "email": "email@example.com",
    "website": "https://your-site.com",
    "twitter": "gentleman_xyz",
    "discord": "gentledev",
    "telegram": "gentle_tech",
    "solana_pubkey": "$SOLANA"
  }
}
EOF

    # systemd unit
    cat <<EOF | sudo tee /etc/systemd/system/popcache.service
[Unit]
Description=POP Cache Node
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$BIN_NAME
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=append:$INSTALL_DIR/logs/stdout.log
StandardError=append:$INSTALL_DIR/logs/stderr.log
Environment=POP_CONFIG_PATH=$INSTALL_DIR/config.json

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}Запускаем сервис...${NC}"
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable popcache
    sudo systemctl start popcache

    echo -e "${GREEN}Открываем порты...${NC}"
    sudo ufw allow 80/tcp || true
    sudo ufw allow 443/tcp || true

    echo -e "${GREEN}Установка завершена. Проверка статуса:${NC}"
    sudo systemctl status popcache --no-pager
}

remove_node() {
    echo -e "${RED}Удаляем POP Cache Node...${NC}"
    sudo systemctl stop popcache
    sudo systemctl disable popcache
    sudo rm -rf $INSTALL_DIR
    sudo rm -f /etc/systemd/system/popcache.service
    sudo systemctl daemon-reload
    echo -e "${GREEN}Нода полностью удалена.${NC}"
}

# Главное меню
animate_loading
CHOICE=$(whiptail --title "PIPE Node Установщик" \
    --menu "Выберите действие:" 16 60 6 \
    "1" "Установить POP Cache Node" \
    "2" "Проверить статус" \
    "3" "Удалить ноду" \
    "4" "Выход" \
    3>&1 1>&2 2>&3)

case $CHOICE in
    1)
        install_node
        ;;
    2)
        echo -e "${BLUE}Статус сервиса:${NC}"
        systemctl status popcache --no-pager
        ;;
    3)
        remove_node
        ;;
    4)
        echo -e "${CYAN}Выход.${NC}"
        ;;
    *)
        echo -e "${RED}Неверный выбор.${NC}"
        ;;
esac
