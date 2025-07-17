#!/bin/bash

# Обновление списка пакетов
echo "Обновляем список пакетов..."
apt update && apt upgrade -y

# Установка Docker, если он не установлен
if ! command -v docker &> /dev/null; then
    echo "Docker не найден. Устанавливаем Docker..."
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker
fi

# Генерация случайного пароля
PASSWORD_LENGTH=24
PASSWORD=$(openssl rand -base64 $PASSWORD_LENGTH | cut -c1-$PASSWORD_LENGTH)

# Создание bcrypt-хеша пароля
PASSWORD_HASH=$(docker run -it ghcr.io/w0rng/amnezia-wg-easy wgpw "$PASSWORD" | grep PASSWORD_HASH | cut -d "'" -f 2)

# Получение IP-адреса сервера (только IPv4)
SERVER_IP=$(curl -4 -s ifconfig.me)

# Генерация случайных портов
WG_PORT=51820
PANEL_PORT=51821

# Запуск WG Easy в Docker
echo "Запускаем WG Easy с конфигурацией..."
docker run --detach \
  --name wg-easy \
  --env LANG=en \
  --env WG_HOST=$SERVER_IP \
  --env PASSWORD_HASH="$PASSWORD_HASH" \
  --env PORT=$PANEL_PORT \
  --env WG_PORT=$WG_PORT \
  --volume ~/.wg-easy:/etc/wireguard \
  --publish $WG_PORT:$WG_PORT/udp \
  --publish $PANEL_PORT:$PANEL_PORT/tcp \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl 'net.ipv4.conf.all.src_valid_mark=1' \
  --sysctl 'net.ipv4.ip_forward=1' \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy

# Вывод данных для пользователя
echo "Установка завершена!"
echo "Вы можете получить доступ к панели WG Easy по адресу:"
echo "wg-interface: http://$SERVER_IP:$PANEL_PORT"
echo "Пароль администратора: $PASSWORD"
