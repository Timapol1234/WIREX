#!/usr/bin/env bash
# Чинит корраптнутые конфиги Hysteria на всех серверах + деплоит фикс
# хелперной библиотеки hysteria_config.py на Амстердам.
#
# Причина: старая версия _extract_users_block делала подстрочное сравнение
# маркеров, из-за чего шапка-комментарий со словами BYPASS-USERS-BEGIN/END
# давала ложный триггер. В итоге __seed__ и salamander.password оказывались
# ВНУТРИ маркеров, а Hysteria падал на дубликате __seed__.
#
# Запускать на Амстердаме.

set -e

REPO=https://github.com/Timapol1234/bypass.git
DEPLOY_DIR=/tmp/bypass-deploy

declare -A SERVERS=(
    [amsterdam]="109.248.162.180"
    [usa]="31.56.229.94"
    [finland]="109.248.161.20"
    [france]="45.38.23.141"
)

echo ">>> 1. Обновляю клон репозитория"
rm -rf "$DEPLOY_DIR"
git clone "$REPO" "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
echo "  последний коммит: $(git log --oneline -1)"

echo ""
echo ">>> 2. Копирую app.py + hysteria_config.py в /opt/vpn-site/"
cp "$DEPLOY_DIR/site/app.py" /opt/vpn-site/app.py
cp "$DEPLOY_DIR/site/hysteria_config.py" /opt/vpn-site/hysteria_config.py
md5sum "$DEPLOY_DIR/site/app.py" /opt/vpn-site/app.py
md5sum "$DEPLOY_DIR/site/hysteria_config.py" /opt/vpn-site/hysteria_config.py

echo ""
echo ">>> 3. Рестарт vpn-site"
systemctl restart vpn-site
sleep 2
systemctl is-active vpn-site && echo "  vpn-site активен"

echo ""
echo ">>> 3b. Проверка что /api/hy-auth поднялся (не 404)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    -d '{"addr":"test","auth":"","tx":0}' \
    http://127.0.0.1:8080/api/hy-auth)
echo "  /api/hy-auth вернул HTTP $code (401 = endpoint жив, 404 = app.py не обновился)"
if [ "$code" = "404" ]; then
    echo "  !!! /api/hy-auth не найден. Проверь что свежий app.py скопировался."
    exit 1
fi

echo ""
echo ">>> 4. Запускаю install_hysteria.sh локально на Амстердаме"
# Чистим старое iptables правило на 8443, если есть
iptables -D INPUT -p udp --dport 8443 -j ACCEPT 2>/dev/null || true
bash "$DEPLOY_DIR/site/install_hysteria.sh" 2>&1 | tail -20
echo "  статус hysteria-server на amsterdam: $(systemctl is-active hysteria-server)"

echo ""
echo ">>> 5. Перезаливаю install_hysteria.sh + запускаю на удалённых серверах"
for key in usa finland france; do
    ip="${SERVERS[$key]}"
    echo ""
    echo "--- $key ($ip) ---"

    # Копируем свежий installer
    scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        "$DEPLOY_DIR/site/install_hysteria.sh" "root@$ip:/root/install_hysteria.sh"

    # Чистим старое iptables правило на 8443, если есть + запускаем installer
    ssh -n -o BatchMode=yes "root@$ip" '
        iptables -D INPUT -p udp --dport 8443 -j ACCEPT 2>/dev/null || true
        bash /root/install_hysteria.sh 2>&1 | tail -20
    '

    # Финальная проверка
    echo "  статус hysteria-server на $key:"
    ssh -n "root@$ip" 'systemctl is-active hysteria-server'
done

echo ""
echo ">>> 6. Проверка: auth-блок во всех конфигах — http-колбэк"
BAD=0

check_auth() {
    local label="$1"
    local cmd="$2"
    local has_http has_userpass
    has_http=$(eval "$cmd" | grep -c 'type: http' || true)
    has_userpass=$(eval "$cmd" | grep -c 'type: userpass' || true)
    if [ "$has_http" = "1" ] && [ "$has_userpass" = "0" ]; then
        echo "  $label: auth=http (OK)"
    else
        echo "  $label: auth НЕ обновлён (http=$has_http userpass=$has_userpass)"
        BAD=1
    fi
}

check_auth "amsterdam" "cat /etc/hysteria/config.yaml"
for key in usa finland france; do
    ip="${SERVERS[$key]}"
    check_auth "$key" "ssh -n root@$ip cat /etc/hysteria/config.yaml"
done

echo ""
if [ "$BAD" -eq 0 ]; then
    echo "=== ВСЁ ОК: все серверы перешли на auth.type=http ==="
else
    echo "=== ВНИМАНИЕ: где-то остался старый auth-блок, проверь вручную ==="
    exit 1
fi
