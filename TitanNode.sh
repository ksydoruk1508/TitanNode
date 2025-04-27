#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Логотип (можно заменить на твой)
channel_logo() {
echo -e "${GREEN}"
cat << "EOF"
████████ ██ ████████  █████  ███    ██     ███    ██  ██████  ██████  ███████ 
   ██    ██    ██    ██   ██ ████   ██     ████   ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ███████ ██ ██  ██     ██ ██  ██ ██    ██ ██   ██ █████   
   ██    ██    ██    ██   ██ ██  ██ ██     ██  ██ ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ██   ██ ██   ████     ██   ████  ██████  ██████  ███████ 
   
________________________________________________________________________________________________________________________________________


███████  ██████  ██████      ██   ██ ███████ ███████ ██████      ██ ████████     ████████ ██████   █████  ██████  ██ ███    ██  ██████  
██      ██    ██ ██   ██     ██  ██  ██      ██      ██   ██     ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ████   ██ ██       
█████   ██    ██ ██████      █████   █████   █████   ██████      ██    ██           ██    ██████  ███████ ██   ██ ██ ██ ██  ██ ██   ███ 
██      ██    ██ ██   ██     ██  ██  ██      ██      ██          ██    ██           ██    ██   ██ ██   ██ ██   ██ ██ ██  ██ ██ ██    ██ 
██       ██████  ██   ██     ██   ██ ███████ ███████ ██          ██    ██           ██    ██   ██ ██   ██ ██████  ██ ██   ████  ██████  
                                                                                                                                         
                                                                                                                                        
 ██  ██████  ██       █████  ███    ██ ██████   █████  ███    ██ ████████ ███████                                                         
██  ██        ██     ██   ██ ████   ██ ██   ██ ██   ██ ████   ██    ██    ██                                                             
██  ██        ██     ███████ ██ ██  ██ ██   ██ ███████ ██ ██  ██    ██    █████                                                          
██  ██        ██     ██   ██ ██  ██ ██ ██   ██ ██   ██ ██  ██ ██    ██    ██                                                             
 ██  ██████  ██      ██   ██ ██   ████ ██████  ██   ██ ██   ████    ██    ███████

Donate: 0x0004230c13c3890F34Bb9C9683b91f539E809000                                                                             
                                                                              
EOF
echo -e "${NC}"
}

#!/bin/bash

# Переменная для платформы (будет определена позже)
PLATFORM=""

# Функция для проверки архитектуры и настройки QEMU
check_architecture() {
    echo -e "${BLUE}Проверяем архитектуру системы...${NC}"
    ARCH=$(uname -m)
    echo -e "${CYAN}Архитектура хоста: $ARCH${NC}"

    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        echo -e "${YELLOW}Обнаружена ARM64-система. Настраиваем QEMU для эмуляции amd64...${NC}"
        # Установка QEMU
        sudo apt update
        sudo apt install -y qemu-user-static
        # Регистрация QEMU в Docker
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
        # Перезапуск Docker
        sudo systemctl restart docker
        # Установка платформы для эмуляции
        PLATFORM="--platform linux/amd64"
        echo -e "${GREEN}QEMU настроен. Будет использоваться эмуляция amd64.${NC}"
    else
        echo -e "${GREEN}Система не ARM64. Эмуляция не требуется.${NC}"
        PLATFORM=""
    fi
}

# Функция для установки одной ноды
download_node() {
    echo -e "${BLUE}Начинается установка ноды...${NC}"

    # Проверка наличия папки .titanedge
    if [ -d "$HOME/.titanedge" ]; then
        echo -e "${RED}Папка .titanedge уже существует. Удалите ноду и установите заново. Выход...${NC}"
        return 0
    fi

    # Установка lsof для проверки портов
    sudo apt install lsof -y

    # Проверка портов
    ports=(1234 55702 48710)
    for port in "${ports[@]}"; do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            echo -e "${RED}Ошибка: Порт $port занят. Программа не сможет выполниться.${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Все порты свободны! Сейчас начнётся установка...${NC}\n"

    cd $HOME

    # Обновление и установка зависимостей
    echo -e "${BLUE}Обновляем и устанавливаем необходимые пакеты...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    # Установка Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    else
        echo -e "${YELLOW}Docker уже установлен. Пропускаем.${NC}"
    fi

    # Установка Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${YELLOW}Docker Compose уже установлен. Пропускаем.${NC}"
    fi

    # Проверка архитектуры и настройка QEMU
    check_architecture

    echo -e "${GREEN}Необходимые зависимости были установлены. Запускаем ноду...${NC}"

    # Остановка и удаление существующих контейнеров (если есть)
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    # Загрузка последней версии образа
    echo -e "${BLUE}Загружаем последнюю версию образа nezha123/titan-edge...${NC}"
    docker pull nezha123/titan-edge

    # Проверка архитектуры образа
    echo -e "${BLUE}Проверяем архитектуру образа...${NC}"
    docker inspect nezha123/titan-edge | grep Architecture

    # Запрос HASH
    while true; do
        echo -e "${YELLOW}Введите ваш HASH:${NC}"
        read -p "> " HASH
        if [ ! -z "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH не может быть пустым.${NC}"
    done

    # Запуск временного контейнера для генерации ключа
    echo -e "${BLUE}Запускаем контейнер для генерации приватного ключа...${NC}"
    docker run $PLATFORM --network=host -d -v ~/.titanedge:$HOME/.titanedge --name titan_temp nezha123/titan-edge
    sleep 30  # Даём время на генерацию ключа

    # Проверка наличия ключа
    if [ -f "$HOME/.titanedge/identity/identity.key" ]; then
        echo -e "${GREEN}Приватный ключ успешно сгенерирован!${NC}"
    else
        echo -e "${RED}Ошибка: Приватный ключ не был сгенерирован. Проверяйте логи контейнера titan_temp.${NC}"
        docker logs titan_temp
        docker stop titan_temp
        docker rm titan_temp
        exit 1
    fi

    # Привязка с использованием HASH
    echo -e "${BLUE}Привязываем ноду с использованием HASH...${NC}"
    docker exec titan_temp titan-edge bind --hash="$HASH" https://api-test1.container1.titannet.io/api/v2/device/binding

    # Остановка временного контейнера
    docker stop titan_temp
    docker rm titan_temp

    # Запуск постоянного контейнера
    echo -e "${BLUE}Запускаем постоянный контейнер...${NC}"
    docker run $PLATFORM --network=host -d --restart always -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge

    echo -e "${GREEN}Нода успешно установлена и запущена!${NC}"
}

# Функция для обновления sysctl
update_sysctl_config() {
    local CONFIG_VALUES="
net.core.rmem_max=26214400
net.core.rmem_default=26214400
net.core.wmem_max=26214400
net.core.wmem_default=26214400
"
    local SYSCTL_CONF="/etc/sysctl.conf"

    echo -e "${BLUE}Делаем резервную копию sysctl.conf.bak...${NC}"
    sudo cp "$SYSCTL_CONF" "$SYSCTL_CONF.bak"

    echo -e "${BLUE}Обновляем sysctl.conf с новой конфигурацией...${NC}"
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo -e "${BLUE}Применяем новые настройки...${NC}"
    sudo sysctl -p

    echo -e "${GREEN}Настройки успешно обновлены.${NC}"

    if command -v setenforce &> /dev/null; then
        echo -e "${BLUE}Отключаем SELinux...${NC}"
        sudo setenforce 0
    else
        echo -e "${YELLOW}SELinux не установлен.${NC}"
    fi
}

# Функция для установки 5 нод
many_node() {
    # Остановка существующих контейнеров
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    # Запрос HASH
    echo -e "${YELLOW}Введите ваш HASH:${NC}"
    read -p "> " id

    # Обновление настроек sysctl
    update_sysctl_config

    storage_gb=50
    start_port=1235
    container_count=5  # Устанавливаем 5 нод

    public_ips=$(curl -s https://api.ipify.org)

    if [ -z "$public_ips" ]; then
        echo -e "${RED}Не удалось получить IP-адрес.${NC}"
        exit 1
    fi

    # Пул последней версии образа
    echo -e "${BLUE}Загружаем последнюю версию образа nezha123/titan-edge...${NC}"
    docker pull nezha123/titan-edge

    # Проверка архитектуры образа
    echo -e "${BLUE}Проверяем архитектуру образа...${NC}"
    docker inspect nezha123/titan-edge | grep Architecture

    current_port=$start_port
    for ip in $public_ips; do
        echo -e "${BLUE}Устанавливаем ноды на IP $ip...${NC}"
  
        for ((i=1; i<=container_count; i++)); do
            storage_path="$HOME/titan_storage_${ip}_${i}"
  
            sudo mkdir -p "$storage_path"
            sudo chmod -R 777 "$storage_path"
  
            # Запуск временного контейнера для генерации ключа
            echo -e "${BLUE}Запускаем временный контейнер для генерации ключа для ноды titan_${ip}_${i}...${NC}"
            docker run $PLATFORM -d -v "$storage_path:$HOME/.titanedge/storage" --name "titan_temp_${ip}_${i}" --net=host nezha123/titan-edge
            sleep 30  # Даём время на генерацию ключа

            # Проверка наличия ключа
            if [ -f "$storage_path/identity/identity.key" ]; then
                echo -e "${GREEN}Приватный ключ для ноды titan_${ip}_${i} успешно сгенерирован!${NC}"
            else
                echo -e "${RED}Ошибка: Приватный ключ для ноды titan_${ip}_${i} не был сгенерирован. Проверяйте логи контейнера titan_temp_${ip}_${i}.${NC}"
                docker logs "titan_temp_${ip}_${i}"
                docker stop "titan_temp_${ip}_${i}"
                docker rm "titan_temp_${ip}_${i}"
                exit 1
            fi

            # Настройка config.toml
            docker exec "titan_temp_${ip}_${i}" bash -c "\
                sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' $HOME/.titanedge/config.toml && \
                sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml && \
                echo 'Хранилище titan_${ip}_${i} установлено на $storage_gb GB, порт установлен на $current_port'"

            # Привязка с использованием HASH
            echo -e "${BLUE}Привязываем ноду titan_${ip}_${i} с использованием HASH...${NC}"
            docker exec "titan_temp_${ip}_${i}" titan-edge bind --hash="$id" https://api-test1.container1.titannet.io/api/v2/device/binding

            # Остановка временного контейнера
            docker stop "titan_temp_${ip}_${i}"
            docker rm "titan_temp_${ip}_${i}"

            # Запуск постоянного контейнера
            container_id=$(docker run $PLATFORM -d --restart always -v "$storage_path:$HOME/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)
  
            echo -e "${GREEN}Нода titan_${ip}_${i} запущена с ID контейнера $container_id${NC}"
  
            current_port=$((current_port + 1))
        done
    done
    echo -e "${GREEN}Все 5 нод успешно установлены!${NC}"
}

# Функция для проверки логов
docker_logs() {
    echo -e "${BLUE}Проверяем логи ноды...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        echo -e "${BLUE}Логи контейнера $container_id:${NC}"
        docker logs "$container_id"
    done
    echo -e "${BLUE}Логи выведены. Возвращаемся в меню...${NC}"
}

# Функция для перезапуска ноды
restart_node() {
    echo -e "${BLUE}Перезапускаем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker restart "$container_id"
    done
    echo -e "${GREEN}Нода успешно перезапущена!${NC}"
}

# Функция для остановки ноды
stop_node() {
    echo -e "${BLUE}Останавливаем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker stop "$container_id"
    done
    echo -e "${GREEN}Нода остановлена!${NC}"
}

# Функция для удаления ноды
delete_node() {
    echo -e "${YELLOW}Если уверены, что хотите удалить ноду, введите любую букву (CTRL+C чтобы выйти):${NC}"
    read -p "> " checkjust

    echo -e "${BLUE}Удаляем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    sudo rm -rf $HOME/.titanedge
    sudo rm -rf $HOME/titan_storage_*  # Удаляем дополнительные пути хранения

    echo -e "${GREEN}Нода успешно удалена!${NC}"
}

# Функция для выхода из скрипта
exit_from_script() {
    echo -e "${BLUE}Выход из скрипта...${NC}"
    exit 0
}

# Функция заглушки для channel_logo
channel_logo() {
    echo -e "${CYAN}Запуск скрипта для управления нодой Titan...${NC}"
}

# Главное меню
main_menu() {
    while true; do
        channel_logo
        sleep 2
        echo -e "\n\n${YELLOW}Выберите действие:${NC}"
        echo -e "${CYAN}1. Установить и запустить ноду${NC}"
        echo -e "${CYAN}2. Проверить логи${NC}"
        echo -e "${CYAN}3. Установить 5 нод${NC}"
        echo -e "${CYAN}4. Перезапустить ноду${NC}"
        echo -e "${CYAN}5. Остановить ноду${NC}"
        echo -e "${CYAN}6. Удалить ноду${NC}"
        echo -e "${CYAN}7. Выход${NC}"
        
        echo -e "${YELLOW}Введите номер:${NC} "
        read choice
        case $choice in
            1) download_node ;;
            2) docker_logs ;;
            3) many_node ;;
            4) restart_node ;;
            5) stop_node ;;
            6) delete_node ;;
            7) exit_from_script ;;
            *) echo -e "${RED}Неверный выбор, попробуйте снова.${NC}" ;;
        esac
    done
}

# Запуск главного меню
main_menu
