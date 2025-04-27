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

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Без цвета

download_node() {
    echo -e "${BLUE}Начинается установка ноды...${NC}"

    if [ -d "$HOME/.titanedge" ]; then
        echo -e "${RED}Папка .titanedge уже существует. Удалите ноду и установите заново. Выход...${NC}"
        return 0
    fi

    sudo apt install lsof -y

    ports=(1234 55702 48710)
    for port in "${ports[@]}"; do
        if lsof -i :"$port" | grep -q LISTEN; then
            echo -e "${RED}Ошибка: Порт $port занят. Программа не сможет выполниться.${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}Все порты свободны! Начинаем установку...${NC}\n"

    cd $HOME

    echo -e "${BLUE}Обновляем систему и устанавливаем зависимости...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install nano git gnupg lsb-release apt-transport-https jq screen ca-certificates curl -y

    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker...${NC}"
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
    else
        echo -e "${YELLOW}Docker уже установлен. Пропускаем.${NC}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "${BLUE}Устанавливаем Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${YELLOW}Docker Compose уже установлен. Пропускаем.${NC}"
    fi

    echo -e "${GREEN}Зависимости установлены. Переходим к запуску ноды...${NC}"

    while true; do
        echo -e "${YELLOW}Введите ваш HASH:${NC}"
        read -p "> " HASH
        if [ -n "$HASH" ]; then
            break
        fi
        echo -e "${RED}HASH не может быть пустым.${NC}"
    done

    echo -e "${RED}⚠️ Важно: теперь необходимо устанавливать ноду вручную по актуальной инструкции проекта.${NC}"
    echo -e "${RED}Этот скрипт больше не может автоматизировать установку без актуального Docker-образа.${NC}"
    echo -e "${CYAN}Ваш HASH: ${HASH}${NC}"
}

update_sysctl_config() {
    local CONFIG_VALUES="
net.core.rmem_max=26214400
net.core.rmem_default=26214400
net.core.wmem_max=26214400
net.core.wmem_default=26214400
"
    local SYSCTL_CONF="/etc/sysctl.conf"

    echo -e "${BLUE}Создаём резервную копию sysctl.conf...${NC}"
    sudo cp "$SYSCTL_CONF" "$SYSCTL_CONF.bak"

    echo -e "${BLUE}Добавляем параметры в sysctl.conf...${NC}"
    echo "$CONFIG_VALUES" | sudo tee -a "$SYSCTL_CONF" > /dev/null

    echo -e "${BLUE}Применяем изменения...${NC}"
    sudo sysctl -p

    echo -e "${GREEN}Системные параметры обновлены.${NC}"

    if command -v setenforce &> /dev/null; then
        echo -e "${BLUE}Отключаем SELinux...${NC}"
        sudo setenforce 0
    else
        echo -e "${YELLOW}SELinux не обнаружен.${NC}"
    fi
}

many_node() {
    echo -e "${RED}⚠️ Массовая установка недоступна без нового Docker-образа.${NC}"
    echo -e "${RED}Пожалуйста, следуйте официальным инструкциям проекта.${NC}"
}

docker_logs() {
    echo -e "${BLUE}Просмотр логов всех контейнеров Docker...${NC}"
    docker ps -a --format "{{.ID}}" | while read container_id; do
        docker logs "$container_id"
    done
    echo -e "${BLUE}Логи выведены.${NC}"
}

restart_node() {
    echo -e "${BLUE}Перезапуск всех контейнеров Docker...${NC}"
    docker ps -q | while read container_id; do
        docker restart "$container_id"
    done
    echo -e "${GREEN}Все контейнеры перезапущены.${NC}"
}

stop_node() {
    echo -e "${BLUE}Остановка всех контейнеров Docker...${NC}"
    docker ps -q | while read container_id; do
        docker stop "$container_id"
    done
    echo -e "${GREEN}Все контейнеры остановлены.${NC}"
}

delete_node() {
    echo -e "${YELLOW}Подтвердите удаление ноды (введите любую букву):${NC}"
    read -p "> " _

    echo -e "${BLUE}Удаляем контейнеры и папки...${NC}"
    docker ps -a -q | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    sudo rm -rf $HOME/.titanedge
    sudo rm -rf $HOME/titan_storage_*

    echo -e "${GREEN}Нода удалена.${NC}"
}

exit_from_script() {
    echo -e "${BLUE}Выход из скрипта...${NC}"
    exit 0
}

channel_logo() {
    echo -e "${CYAN}"
    echo "==========================="
    echo "      Titan Node Setup      "
    echo "==========================="
    echo -e "${NC}"
}

main_menu() {
    while true; do
        channel_logo
        sleep 1
        echo -e "\n${YELLOW}Выберите действие:${NC}"
        echo -e "${CYAN}1. Установить и запустить ноду${NC}"
        echo -e "${CYAN}2. Проверить логи${NC}"
        echo -e "${CYAN}3. Установить 5 нод${NC}"
        echo -e "${CYAN}4. Перезапустить ноду${NC}"
        echo -e "${CYAN}5. Остановить ноду${NC}"
        echo -e "${CYAN}6. Удалить ноду${NC}"
        echo -e "${CYAN}7. Выход${NC}"

        read -p "Введите номер: " choice
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
