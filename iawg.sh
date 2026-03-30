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

# Создание bcrypt-хеша пароля для AmneziaWG
echo "Генерируем хеш пароля..."
PASSWORD_HASH=$(docker run --rm ghcr.io/w0rng/amnezia-wg-easy wgpw "$PASSWORD" | grep PASSWORD_HASH | cut -d "'" -f 2 | tr -d '\r')

# Получение IP-адреса сервера (только IPv4)
SERVER_IP=$(curl -4 -s ifconfig.me)

# Проверка, что IP получен
if [ -z "$SERVER_IP" ]; then
    echo "Не удалось получить IP-адрес сервера. Используем fallback метод..."
    SERVER_IP=$(curl -4 -s icanhazip.com)
fi

# Если все еще нет IP, запрашиваем вручную
if [ -z "$SERVER_IP" ]; then
    echo "Введите IP-адрес вашего сервера вручную:"
    read -p "IP адрес: " SERVER_IP
fi

# Настройка параметров
WG_PORT=51820
PANEL_PORT=51821

# Остановка и удаление старого контейнера, если он существует
echo "Останавливаем и удаляем старый контейнер если есть..."
docker rm -f amnezia-wg-easy &> /dev/null

# Создание директории для конфигурации
mkdir -p ~/.amnezia-wg-easy

# Запуск AmneziaWG Easy в Docker
echo "Запускаем AmneziaWG Easy с конфигурацией..."
docker run --detach \
  --name=amnezia-wg-easy \
  --env LANG=en \
  --env WG_HOST="$SERVER_IP" \
  --env PASSWORD_HASH="$PASSWORD_HASH" \
  --env PORT=$PANEL_PORT \
  --env WG_PORT=$WG_PORT \
  --volume ~/.amnezia-wg-easy:/etc/wireguard \
  --publish $WG_PORT:$WG_PORT/udp \
  --publish $PANEL_PORT:$PANEL_PORT/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --sysctl="net.ipv4.ip_forward=1" \
  --device=/dev/net/tun:/dev/net/tun \
  --restart unless-stopped \
  ghcr.io/w0rng/amnezia-wg-easy

# Проверка статуса запуска
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Установка AmneziaWG Easy успешно завершена!"
    echo "=========================================="
    echo ""
    echo "Доступ к панели управления:"
    echo "http://$SERVER_IP:$PANEL_PORT"
    echo ""
    echo "Пароль администратора: $PASSWORD"
    echo ""
    echo "Порт WireGuard: $WG_PORT/udp"
    echo "Порт панели: $PANEL_PORT/tcp"
    echo ""
    echo "Директория с конфигурациями: ~/.amnezia-wg-easy"
    echo ""
    echo "Для просмотра логов выполните:"
    echo "docker logs amnezia-wg-easy"
    echo ""
    echo "Для остановки контейнера:"
    echo "docker stop amnezia-wg-easy"
    echo ""
    echo "Для запуска контейнера:"
    echo "docker start amnezia-wg-easy"
else
    echo "Ошибка при запуске контейнера!"
    exit 1
fi
