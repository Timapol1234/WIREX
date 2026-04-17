#!/bin/bash
# Установка VPN-сайта на сервер
# Запускать: bash setup.sh

set -e

APP_DIR="/opt/vpn-site"
SUB_DIR="/var/www/sub"

echo "=== Установка зависимостей ==="
apt update && apt install -y python3 python3-pip python3-venv sshpass

echo "=== Копирование файлов ==="
mkdir -p "$APP_DIR/static"
mkdir -p "$SUB_DIR"
cp app.py "$APP_DIR/"
cp static/index.html "$APP_DIR/static/"

echo "=== Создание виртуального окружения ==="
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate
pip install flask qrcode[pil]

echo "=== ВАЖНО: Секреты ==="
read -p "Пароль для админ-панели: " ADMIN_PASS
read -p "SMTP логин (mail.ru): " SMTP_USER
read -p "SMTP пароль (app password): " SMTP_PASS

cat > "$APP_DIR/secrets.json" <<EOF
{
  "admin_password": "$ADMIN_PASS",
  "smtp_username": "$SMTP_USER",
  "smtp_password": "$SMTP_PASS"
}
EOF
chmod 600 "$APP_DIR/secrets.json"
echo "Секреты сохранены в $APP_DIR/secrets.json (chmod 600)."

echo "=== Настройка SSH-ключей для удаленных серверов ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
    echo "SSH-ключ создан: ~/.ssh/id_rsa"
fi

echo ""
echo "Теперь нужно скопировать ключ на удаленные серверы:"
echo "Выполните эти команды вручную:"
echo ""
echo "ssh-copy-id root@31.56.229.94"
echo "ssh-copy-id root@109.248.161.20"
echo "ssh-copy-id root@45.38.23.141"
echo ""
read -p "Нажмите Enter, когда скопируете ключи на все серверы..."

echo "=== Проверка подключения к удаленным серверам ==="
for server in root@31.56.229.94 root@109.248.161.20 root@45.38.23.141; do
    echo -n "Проверка $server... "
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$server" "echo OK" 2>/dev/null; then
        echo "✅"
    else
        echo "❌ ОШИБКА! Проверьте SSH-ключ"
    fi
done

echo "=== Создание systemd сервиса ==="
cat > /etc/systemd/system/vpn-site.service <<EOF
[Unit]
Description=VPN Keys Website
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "=== Запуск сайта ==="
systemctl daemon-reload
systemctl enable vpn-site
systemctl restart vpn-site

echo ""
echo "========================================="
echo "  Сайт запущен!"
echo ""
echo "  Ссылка для пользователей:"
echo "  http://109.248.162.180:8080/"
echo "  (авторизация через email OTP, токен-приглашение больше не нужен)"
echo ""
echo "  Админ-панель (только для тебя):"
echo "  http://109.248.162.180:8080/?admin=1"
echo "  Пароль: $ADMIN_PASS"
echo ""
echo "  Подписки для клиентов:"
echo "  http://109.248.162.180:8080/sub/ИМЯ_ПОЛЬЗОВАТЕЛЯ"
echo "========================================="