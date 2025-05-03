#!/bin/bash

# Проверка и установка нужных утилит
for util in figlet whiptail curl docker iptables jq; do
  if ! command -v "$util" &>/dev/null; then
    echo "$util не найден. Устанавлию..."
    sudo apt update && sudo apt install -y "$util"
  fi
done

# Цветовые константы
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
NC="\e[0m"

clear
# Приветствие
echo -e "${CYAN}$(figlet -w 150 -f standard \"Soft by The Gentleman\")${NC}"
echo "================================================================"
echo "      Добро пожаловать в мастер установки ноды Aztec от Джентльмена       "
echo "================================================================"

echo -e "${YELLOW}Подписывайтесь на Telegram: https://t.me/GentleChron${NC}"
echo -e "${CYAN}Продолжение через 10 секунд...${NC}"
sleep 10

# Анимация загрузки
animate() {
  for i in {1..3}; do
    printf "\r${GREEN}Загрузка${NC}%s" "$(printf '.%.0s' $(seq 1 $i))"
    sleep 0.4
  done
  echo
}
animate

# Главное меню через whiptail
CHOICE=$(whiptail --title "Aztec Node Control" \
  --menu "Выберите действие:" 15 60 5 \
    "1" "Установить ноду" \
    "2" "Показать логи" \
    "3" "Проверить хеш" \
    "4" "Зарегистрировать валидатора" \
    "5" "Удалить ноду" \
  3>&1 1>&2 2>&3)

# Если пользователь нажал Esc или Cancel
if [ $? -ne 0 ]; then
  echo -e "${RED}Отмена. Выход.${NC}"
  exit 1
fi

# Благодарность
give_ack() {
  echo
  echo -e "${CYAN}Спасибо! Подписывайтесь: https://t.me/GentleChron${NC}"
}

case "$CHOICE" in

  1)
    echo -e "${GREEN}Готовлю окружение...${NC}"
    # <…тут ваш оригинальный код установки…>
    give_ack
    ;;

  2)
    echo -e "${GREEN}Показываю логи...${NC}"
    # <…оригинал…>
    give_ack
    ;;

  3)
    echo -e "${GREEN}Запрос хеша...${NC}"
    # <…оригинал…>
    give_ack
    ;;

  4)
    echo -e "${GREEN}Запускаю процедуру регистрации валидатора...${NC}"
    # <…оригинал…>
    give_ack
    ;;

  5)
    echo -e "${RED}Удаляю ноду...${NC}"
    # <…оригинал…>
    give_ack
    ;;

  *)
    echo -e "${RED}Неверный выбор. Выход.${NC}"
    exit 1
    ;;
esac
