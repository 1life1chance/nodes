#!/usr/bin/env bash
set -euo pipefail

# Файл с параметрами ноды
VARS_FILE="$HOME/aztec-sequencer/.env"
if [ -f "$VARS_FILE" ]; then
  export $(grep -v '^\s*#' "$VARS_FILE" | xargs)
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Выполняем команду добавления валидатора и сохраняем вывод
echo -e "${GREEN}Запускаем процесс добавления валидатора...${NC}"
RAW_OUT=$(docker exec -i aztec-sequencer \
  sh -c 'node /usr/src/yarn-project/aztec/dest/bin/index.js add-l1-validator \
    --l1-rpc-urls "${ETHEREUM_HOSTS}" \
    --private-key "${VALIDATOR_PRIVATE_KEY}" \
    --attester "${WALLET}" \
    --proposer-eoa "${WALLET}" \
    --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
    --l1-chain-id 11155111' 2>&1) || true

# Обработка превышения квоты
if echo "$RAW_OUT" | grep -q 'ValidatorQuotaFilledUntil'; then
  TS=$(echo "$RAW_OUT" | grep -oP '(?<=\()[0-9]+(?=\))' | head -n1)
  NOW=$(date +%s)
  DELTA=$(( TS - NOW ))
  HOURS=$(( DELTA / 3600 ))
  MINS=$(( (DELTA % 3600) / 60 ))
  printf "${RED}Извините, квота по регистрации валидаторов временно исчерпана.\n"
  printf "Попробуйте снова через %d ч %d м.${NC}\n" "$HOURS" "$MINS"
else
  # В остальных случаях выводим оригинальный ответ команды
  echo "$RAW_OUT"
fi
