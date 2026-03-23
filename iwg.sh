#!/bin/bash

# Обновление списка пакетов
echo "Обновляем список пакетов..."
apt update && apt upgrade -y

# Установка Docker, если он не установлен
if ! command -v docker &> /dev/null; then
    echo "Docker не найден. Устанавливаем Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    systemctl start docker
    systemctl enable docker
fi

# Генерация случайного пароля
PASSWORD_LENGTH=24
PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c $PASSWORD_LENGTH)

# Создание bcrypt-хеша пароля
PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD" | grep PASSWORD_HASH | cut -d "'" -f 2 | tr -d '\r')

# Получение IP-адреса сервера (только IPv4)
SERVER_IP=$(curl -4 -s ifconfig.me)

# Генерация случайных портов
WG_PORT=51820
PANEL_PORT=51821

# Удаление старого контейнера, если он существует
docker rm -f wg-easy &> /dev/null

# Запуск WG Easy в Docker
echo "Запускаем WG Easy с конфигурацией..."
docker run --detach \
  --name wg-easy \
  --env LANG=en \
  --env WG_HOST=$SERVER_IP \
  --env PASSWORD_HASH="$PASSWORD_HASH" \
  --env PORT=$PANEL_PORT \
  --env WG_PORT=$WG_PORT \
  --volume ~/.wg-easy:/etc/guard \
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
