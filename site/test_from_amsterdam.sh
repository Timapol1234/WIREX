#!/usr/bin/env bash
# Тест подключения Амстердам → Финляндия как hysteria-клиент.
# Если работает — значит сервер ОК, проблема в сети между клиентом юзера и Финляндией.
# Если не работает — проблема на сервере Финляндия.

set -uo pipefail

FIN_IP="109.248.161.20"
UN="tpoltarykhin5555"
HY_PW="9307teeYuvsXpDvOvwEDp0fa"

# 1. Проверяем что hysteria-клиент есть. Бинарник один — и сервер и клиент.
which hysteria || bash <(curl -fsSL https://get.hy2.sh/)

# 2. Пишем клиентский конфиг
cat > /tmp/hy-client.yaml <<EOF
server: $FIN_IP:8443
auth: $UN:$HY_PW
tls:
  sni: www.microsoft.com
  insecure: true
socks5:
  listen: 127.0.0.1:11080
bandwidth:
  up: 10 mbps
  down: 50 mbps
EOF

echo "=== Клиентский конфиг ==="
cat /tmp/hy-client.yaml
echo ""

echo "=== Запускаю hysteria-клиент на 15 секунд ==="
# Запустим в фоне, проверим что подключилось, убьём
timeout 15 hysteria client -c /tmp/hy-client.yaml >/tmp/hy-client.log 2>&1 &
HY_PID=$!

# Даём ему 4 сек на handshake
sleep 4

echo "=== Логи клиента ==="
cat /tmp/hy-client.log
echo ""

if ! kill -0 $HY_PID 2>/dev/null; then
    echo "[FAIL] клиент hysteria уже упал — смотри логи выше"
    exit 1
fi

echo "=== Пробую проксировать запрос через SOCKS5 ==="
RESULT=$(curl -s -x socks5h://127.0.0.1:11080 --max-time 10 https://api.ipify.org 2>&1)
if [ -n "$RESULT" ]; then
    echo "IP, который мир видит через прокси: $RESULT"
    if [ "$RESULT" = "$FIN_IP" ]; then
        echo "[OK] Туннель работает, пакеты выходят из Финляндии"
    else
        echo "[WEIRD] Ответ получен, но IP не Финляндии: $RESULT"
    fi
else
    echo "[FAIL] curl через SOCKS5 не вернул ничего — туннель не установился"
fi

echo ""
echo "=== Убиваю клиент ==="
kill $HY_PID 2>/dev/null || true
wait $HY_PID 2>/dev/null || true

echo ""
echo "=== Финальные логи клиента ==="
cat /tmp/hy-client.log
