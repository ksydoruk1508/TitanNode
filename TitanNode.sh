#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета

# Определение архитектуры и установка переменной образа
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    DOCKER_IMAGE="nezha123/titan-edge"
elif [[ "$ARCH" == "aarch64" ]]; then
    DOCKER_IMAGE="nezha123/titan-edge:1.5"
else
    echo -e "${RED}Неподдерживаемая архитектура: $ARCH${NC}"
    exit 1
fi

# Проверка наличия curl и установка, если нет
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

channel_logo() {
echo -e "${GREEN}"
cat << "EOF"
████████ ██ ████████  █████  ███    ██     ███    ██  ██████  ██████  ███████ 
   ██    ██    ██    ██   ██ ████   ██     ████   ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ███████ ██ ██  ██     ██ ██  ██ ██    ██ ██   ██ █████   
   ██    ██    ██    ██   ██ ██  ██ ██     ██  ██ ██ ██    ██ ██   ██ ██      
   ██    ██    ██    ██   ██ ██   ████     ██   ████  ██████  ██████  ███████ 

Donate: 0x0004230c13c3890F34Bb9C9683b91f539E809000
EOF
echo -e "${NC}"
}

download_node() {
    echo -e "${BLUE}Начинается установка ноды...${NC}"

    if [ -d "$HOME/.titanedge" ]; then
        echo -e "${RED}Папка .titanedge уже существует. Удалите ноду и установите заново.${NC}"
        return 0
    fi

    sudo apt install lsof -y

    ports=(1234 55702 48710)
    for port in "${ports[@]}"; do
        if lsof -i :"$port" | grep LISTEN; then
            echo -e "${RED}Порт $port занят.${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Все порты свободны!${NC}"

    cd $HOME

    sudo apt update -y && sudo apt upgrade -y
    sudo apt install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    else
        echo -e "${YELLOW}Docker уже установлен.${NC}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${YELLOW}Docker Compose уже установлен.${NC}"
    fi

    echo -e "${GREEN}Запускаем ноду...${NC}"

    docker ps -a --filter "ancestor=$DOCKER_IMAGE" --format "{{.ID}}" | xargs -r docker rm -f

    while true; do
        echo -e "${YELLOW}Введите ваш HASH:${NC}"
        read -p "> " HASH
        if [ ! -z "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH не может быть пустым.${NC}"
    done

    docker run --network=host -d -v ~/.titanedge:$HOME/.titanedge $DOCKER_IMAGE
    sleep 10
    docker run --rm -it -v ~/.titanedge:$HOME/.titanedge $DOCKER_IMAGE bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding

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

    echo -e "${BLUE}Создаём резервную копию sysctl.conf.bak...${NC}"
    sudo cp "$SYSCTL_CONF" "$SYSCTL_CONF.bak"

    echo -e "${BLUE}Добавляем новые параметры в sysctl.conf...${NC}"
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo -e "${BLUE}Применяем изменения...${NC}"
    sudo sysctl -p

    if command -v setenforce &> /dev/null; then
        echo -e "${BLUE}Отключаем SELinux...${NC}"
        sudo setenforce 0
    fi
}

many_node() {
    docker ps -a --filter "ancestor=$DOCKER_IMAGE" --format "{{.ID}}" | xargs -r docker rm -f

    echo -e "${YELLOW}Введите ваш HASH:${NC}"
    read -p "> " HASH

    update_sysctl_config

    storage_gb=50
    start_port=1235
    container_count=5

    public_ip=$(curl -s https://api.ipify.org)

    if [ -z "$public_ip" ]; then
        echo -e "${RED}Не удалось получить IP.${NC}"
        exit 1
    fi

    docker pull $DOCKER_IMAGE

    current_port=$start_port
    for ((i=1; i<=container_count; i++)); do
        storage_path="$HOME/titan_storage_${i}"
  
        sudo mkdir -p "$storage_path"
        sudo chmod -R 777 "$storage_path"
  
        container_id=$(docker run -d --restart always -v "$storage_path:$HOME/.titanedge/storage" --name "titan_${i}" --net=host $DOCKER_IMAGE)
  
        echo -e "${GREEN}Нода titan_${i} запущена с ID контейнера $container_id${NC}"
  
        sleep 30
  
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' $HOME/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml"

        docker restart $container_id

        docker exec $container_id bash -c "\
            titan-edge bind --hash=$HASH https://api-test1.container1.titannet.io/api/v2/device/binding"
  
        echo -e "${GREEN}Нода titan_${i} успешно установлена.${NC}"

        current_port=$((current_port + 1))
    done
}

docker_logs() {
    echo -e "${BLUE}Вывод логов контейнеров...${NC}"
    docker ps -a --filter "ancestor=$DOCKER_IMAGE" --format "{{.ID}}" | xargs -r docker logs
}

restart_node() {
    echo -e "${BLUE}Перезапуск контейнеров...${NC}"
    docker ps -a --filter "ancestor=$DOCKER_IMAGE" --format "{{.ID}}" | xargs -r docker restart
}

stop_node() {
    echo -e "${BLUE}Остановка контейнеров...${NC}"
    docker ps -a --filter "ancestor=$DOCKER_IMAGE" --format "{{.ID}}" | xargs -r docker stop
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
