#!/usr/bin/env bash
# Смотрит, что видит hysteria-server в момент попытки клиента подключиться.
# Запускать на Амстердаме сразу после нажатия Connect в V2Box.

set -uo pipefail

declare -A IPS=(
    [amsterdam]="109.248.162.180"
    [usa]="31.56.229.94"
    [finland]="109.248.161.20"
    [france]="45.38.23.141"
)

SERVER=$(python3 -c "import json; print(json.load(open('/opt/vpn-site/users.json'))[-1]['server'])")
SERVER_IP="${IPS[$SERVER]}"
UN=$(python3 -c "import json; print(json.load(open('/opt/vpn-site/users.json'))[-1]['username'])")

echo "=== Последний юзер: $UN на $SERVER ($SERVER_IP) ==="
echo ""

echo "=== Логи hysteria-server за последние 2 минуты ==="
ssh -n "root@$SERVER_IP" 'journalctl -u hysteria-server --since "2 minutes ago" --no-pager'

echo ""
echo "=== UDP трафик на порт 8443 за 10 секунд (tcpdump) ==="
echo "(попробуй прямо сейчас нажать Connect в V2Box)"
ssh -n "root@$SERVER_IP" 'timeout 10 tcpdump -ni any -c 20 "udp port 8443" 2>&1 || true'

echo ""
echo "=== Что изменилось в логах hysteria за это время ==="
ssh -n "root@$SERVER_IP" 'journalctl -u hysteria-server --since "30 seconds ago" --no-pager'

echo ""
echo "=== TCP/UDP счётчики на порт 8443 (ufw/iptables) ==="
ssh -n "root@$SERVER_IP" 'iptables -L INPUT -v -n | grep -E "8443|Chain INPUT" || true'
