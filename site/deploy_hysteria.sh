#!/usr/bin/env bash
# Финальный деплой: обновляет secrets.json с obfs passwords,
# подтягивает последний код из git и перезапускает vpn-site.
# Запускать на Амстердаме.

set -e

echo ">>> Обновляю /opt/vpn-site/secrets.json"
python3 <<'PYEOF'
import json
p = "/opt/vpn-site/secrets.json"
d = json.load(open(p))
d["hysteria"] = {
    "amsterdam": {"obfs_password": "RpIc8oNqLhMse0HqFQBfeGrwC372Vws4"},
    "usa":       {"obfs_password": "SpP9WQ5RKvjC5NSPNFTEFeVxuQ6W7lTd"},
    "finland":   {"obfs_password": "BKuBFtgom2dGm2AoMqN4JH72oEthnoj3"},
    "france":    {"obfs_password": "4QFtuNsl6Ghq2lsoyaTaJOmtOw70PJWD"},
}
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
print("  secrets.json updated")
PYEOF

echo ""
echo ">>> git pull в /tmp/bypass-deploy"
cd /tmp/bypass-deploy
git pull

echo ""
echo ">>> Копирую свежий код в /opt/vpn-site"
cp site/app.py site/hysteria_config.py site/index.html /opt/vpn-site/

echo ""
echo ">>> Перезапускаю vpn-site"
systemctl restart vpn-site
sleep 2

echo ""
echo ">>> Статус:"
systemctl status vpn-site --no-pager | head -5

echo ""
echo "=== ГОТОВО ==="
echo "Теперь открой сайт, удали старые ключи, создай новый."
echo "У нового ключа должна быть вкладка Hysteria 2."
