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

# Функция для определения архитектуры и настройки QEMU
setup_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        DOCKER_PLATFORM_OPTION=""
    elif [[ "$ARCH" == "aarch64" ]]; then
        DOCKER_PLATFORM_OPTION="--platform linux/amd64"
        echo -e "${YELLOW}Обнаружена ARM64-система. Настраиваем QEMU для эмуляции amd64...${NC}"
        # Установка qemu-user и qemu-user-static
        sudo apt update
        sudo apt install -y qemu-user qemu-user-static
        # Проверка наличия qemu-x86_64
        if ! command -v qemu-x86_64 &> /dev/null; then
            echo -e "${RED}Ошибка: qemu-x86_64 не найден после установки. Эмуляция невозможна. Выход...${NC}"
            exit 1
        fi
        echo -e "${GREEN}qemu-x86_64 установлен: $(qemu-x86_64 --version)${NC}"
        # Проверка binfmt_misc
        if [ ! -d "/proc/sys/fs/binfmt_misc" ]; then
            echo -e "${BLUE}Включаем binfmt_misc...${NC}"
            sudo modprobe binfmt_misc
            sudo systemctl enable --now systemd-binfmt
        fi
        # Проверка существующей регистрации QEMU
        if [ -f "/proc/sys/fs/binfmt_misc/qemu-x86_64" ]; then
            echo -e "${GREEN}QEMU уже зарегистрирован для эмуляции amd64.${NC}"
        else
            # Ручная регистрация QEMU
            echo -e "${BLUE}Регистрируем QEMU вручную...${NC}"
            if ! sudo update-binfmts --install qemu-x86_64 /usr/bin/qemu-x86_64 --magic '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00' --mask '\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'; then
                echo -e "${RED}Ошибка: Не удалось зарегистрировать QEMU вручную. Эмуляция amd64 невозможна. Выход...${NC}"
                exit 1
            fi
        fi
        # Перезапуск Docker
        sudo systemctl restart docker
        echo -e "${GREEN}QEMU настроен. Будет использоваться эмуляция amd64.${NC}"
    else
        echo -e "${RED}Неизвестная архитектура: $ARCH${NC}"
        exit 1
    fi
}

download_node() {
    echo -e "${BLUE}Начинается установка ноды...${NC}"

    if [ -d "$HOME/.titanedge" ]; then
        echo -e "${RED}Папка .titanedge уже существует. Удалите ноду и установите заново. Выход...${NC}"
        return 0
    fi

    # Настройка архитектуры и QEMU
    setup_architecture

    sudo apt install lsof -y

    ports=(1234 55702 48710)
    for port in "${ports[@]}"; do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            echo -e "${RED}Ошибка: Порт $port занят. Программа не сможет выполниться.${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Все порты свободны! Сейчас начнётся установка...${NC}\n"

    cd $HOME

    echo -e "${BLUE}Обновляем и устанавливаем необходимые пакеты...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    else
        echo -e "${YELLOW}Docker уже установлен. Пропускаем.${NC}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${YELLOW}Docker Compose уже установлен. Пропускаем.${NC}"
    fi

    echo -e "${GREEN}Необходимые зависимости были установлены. Запускаем ноду...${NC}"

    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    while true; do
        echo -e "${YELLOW}Введите ваш HASH:${NC}"
        read -p "> " HASH
        if [ ! -z "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH не может быть пустым.${NC}"
    done

    docker run $DOCKER_PLATFORM_OPTION --network=host -d -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge
    sleep 10

    docker run $DOCKER_PLATFORM_OPTION --rm -it -v ~/.titanedge:$HOME/.titanedge nezha123/titan-edge bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding

    echo -e "${GREEN}Нода успешно установлена и запущена!${NC}"
}

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

# Функция ожидания готовности контейнера
wait_for_container() {
    local container_id=$1
    local timeout=60
    local elapsed=0
    local interval=5

    echo -e "${BLUE}Ожидаем, пока контейнер $container_id перейдёт в состояние running...${NC}"
    while [ $elapsed -lt $timeout ]; do
        if docker inspect --format='{{.State.Status}}' "$container_id" | grep -q "running"; then
            echo -e "${GREEN}Контейнер $container_id готов!${NC}"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo -e "${RED}Ошибка: Контейнер $container_id не перешёл в состояние running за $timeout секунд. Проверяйте логи контейнера.${NC}"
    docker logs "$container_id"
    exit 1
}

many_node() {
    # Остановка существующих контейнеров
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | shuf -n $(docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | wc -l) | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    # Настройка архитектуры и QEMU
    setup_architecture

    # Запрос HASH
    echo -e "${YELLOW}Введите ваш HASH:${NC}"
    read -p "> " id

    # Обновление настроек sysctl
    update_sysctl_config

    storage_gb=50
    start_port=1235
    container_count=5  # Устанавливаем 5 нод

    # Проверка портов
    echo -e "${BLUE}Проверяем доступность портов...${NC}"
    for ((port=start_port; port<start_port+container_count; port++)); do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            echo -e "${RED}Ошибка: Порт $port занят. Программа не сможет выполниться.${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}Все порты свободны!${NC}"

    public_ips=$(curl -s https://api.ipify.org)

    if [ -z "$public_ips" ]; then
        echo -e "${RED}Не удалось получить IP-адрес.${NC}"
        exit 1
    fi

    # Пул образа
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
  
            # Создаём config.toml с правильным портом до запуска контейнера
            echo -e "${BLUE}Создаём config.toml для ноды titan_${ip}_${i}...${NC}"
            mkdir -p "$storage_path"
            cat > "$storage_path/config.toml" <<EOF
StorageGB = $storage_gb
ListenAddress = "0.0.0.0:$current_port"
EOF

            # Запуск контейнера
            container_id=$(docker run $DOCKER_PLATFORM_OPTION -d --restart always -v "$storage_path:$HOME/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)
  
            echo -e "${GREEN}Нода titan_${ip}_${i} запущена с ID контейнера $container_id${NC}"
  
            # Ожидаем готовности контейнера
            wait_for_container "$container_id"

            # Даём время на генерацию ключа
            echo -e "${BLUE}Ожидаем генерацию ключа для ноды titan_${ip}_${i}...${NC}"
            sleep 60
  
            # Привязка с использованием HASH
            echo -e "${BLUE}Привязываем ноду titan_${ip}_${i} с использованием HASH...${NC}"
            if ! docker exec $container_id titan-edge bind --hash="$id" https://api-test1.container1.titannet.io/api/v2/device/binding; then
                echo -e "${RED}Ошибка при привязке ноды titan_${ip}_${i}. Проверяйте логи контейнера.${NC}"
                docker logs "$container_id"
                exit 1
            fi

            echo -e "${GREEN}Нода titan_${ip}_${i} успешно установлена.${NC}"
  
            current_port=$((current_port + 1))
        done
    done
    echo -e "${GREEN}Все 5 нод успешно установлены!${NC}"
}

docker_logs() {
    echo -e "${BLUE}Проверяем логи ноды...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker logs "$container_id"
    done
    echo -e "${BLUE}Логи выведены. Возвращаемся в меню...${NC}"
}

restart_node() {
    echo -e "${BLUE}Перезапускаем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker restart "$container_id"
    done
    echo -e "${GREEN}Нода успешно перезапущена!${NC}"
}

stop_node() {
    echo -e "${BLUE}Останавливаем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker stop "$container_id"
    done
    echo -e "${GREEN}Нода остановлена!${NC}"
}

delete_node() {
    echo -e "${YELLOW}Если уверены, что хотите удалить ноду, введите любую букву (CTRL+C чтобы выйти):${NC}"
    read -p "> " checkjust

    echo -e "${BLUE}Удаляем ноду...${NC}"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    sudo rm -rf $HOME/.titanedge
    sudo rm -rf $HOME/titan_storage_*

    echo -e "${GREEN}Нода успешно удалена!${NC}"
}

exit_from_script() {
    echo -e "${BLUE}Выход из скрипта...${NC}"
    exit 0
}

channel_logo() {
    echo -e "${CYAN}Запуск скрипта для управления нодой Titan...${NC}"
}

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

main_menu
