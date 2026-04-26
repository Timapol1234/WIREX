#!/usr/bin/env bash
# Поднимает nginx + Let's Encrypt сертификат для api.wirex.online на бэкенде.
# Проксирует https://api.wirex.online:8443 → 127.0.0.1:8080 (Flask).
# Запускать один раз на сервере 109.248.162.180 как root.
#
# Почему 8443, а не 443:
#   На :443 уже сидит Xray (VLESS + Reality), его нельзя подвинуть — отвалятся
#   все клиенты VPN. nginx для API живёт на отдельном порту, certbot выпускает
#   серт через HTTP-01 challenge на :80 (там ничего нет, проверено).
#
# Предусловие: A-запись api.wirex.online → 109.248.162.180 уже распространилась.
# Проверь: getent hosts api.wirex.online должно вернуть 109.248.162.180.

set -e

DOMAIN="api.wirex.online"
EMAIL="bigamkavinsjcmibs@outlook.com"   # для Let's Encrypt уведомлений
HTTPS_PORT=8443
FLASK_PORT=8080

echo "=== 1. Ставлю nginx + certbot ==="
apt update
apt install -y nginx certbot python3-certbot-nginx ufw

echo "=== 2. Открываю 80/${HTTPS_PORT} в ufw (если ufw активен) ==="
if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp
    ufw allow ${HTTPS_PORT}/tcp
fi

echo "=== 3. Проверяю, что :80 свободен ==="
if ss -tlnp | grep -q ':80 '; then
    echo "  ОШИБКА: :80 уже занят. Кто-то слушает 80-й порт:"
    ss -tlnp | grep ':80 '
    echo "  Останови этот сервис и перезапусти скрипт."
    exit 1
fi

echo "=== 4. Базовый http-конфиг для certbot challenge ==="
cat > /etc/nginx/sites-available/api-wirex.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host:${HTTPS_PORT}\$request_uri;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/api-wirex.conf /etc/nginx/sites-enabled/api-wirex.conf
rm -f /etc/nginx/sites-enabled/default

mkdir -p /var/www/html
nginx -t
systemctl reload nginx || systemctl start nginx

echo "=== 5. Выпуск Let's Encrypt cert'а через webroot (HTTP-01 на :80) ==="
certbot certonly --webroot -w /var/www/html -d "${DOMAIN}" \
    --non-interactive --agree-tos -m "${EMAIL}"

echo "=== 6. Финальный конфиг с reverse-proxy на Flask (HTTPS :${HTTPS_PORT}) ==="
cat > /etc/nginx/sites-available/api-wirex.conf <<NGINX
# HTTP — отвечает на ACME challenge и редиректит на нестандартный HTTPS-порт
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host:${HTTPS_PORT}\$request_uri;
    }
}

# HTTPS API на :${HTTPS_PORT} — :443 занят Xray-Reality, поэтому отдельный порт
server {
    listen ${HTTPS_PORT} ssl http2;
    listen [::]:${HTTPS_PORT} ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 2m;

    location / {
        proxy_pass http://127.0.0.1:${FLASK_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Connection        "";
        proxy_read_timeout 300s;
    }
}
NGINX

nginx -t
systemctl reload nginx

echo "=== 7. Проверка cron auto-renew ==="
systemctl list-timers 2>/dev/null | grep -qi certbot && echo "  certbot.timer активен ✓" || echo "  ВНИМАНИЕ: certbot.timer не найден — настрой renew вручную"

echo ""
echo "=========================================="
echo "  ГОТОВО. Проверь:"
echo "    curl -I https://${DOMAIN}:${HTTPS_PORT}/api/health"
echo "    → HTTP 200 + правильный TLS"
echo ""
echo "  Flask на 8080 НЕ закрывай — nginx ходит туда по 127.0.0.1."
echo "  В коде фронта API_URL должен быть: https://${DOMAIN}:${HTTPS_PORT}"
echo "=========================================="
