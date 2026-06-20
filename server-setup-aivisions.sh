#!/bin/bash

set -e

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
plain='\033[0m'

# Цветовые коды для read -p (с маркерами readline для игнорирования непечатных символов)
read_red=$'\001\033[0;31m\002'
read_green=$'\001\033[0;32m\002'
read_yellow=$'\001\033[1;33m\002'
read_plain=$'\001\033[0m\002'

# Открываем /dev/tty как file descriptor 3 для интерактивного ввода
# Это позволяет скрипту работать даже при запуске через bash <(curl ...)
exec 3<>/dev/tty

echo -e "${green}========================================${plain}"
echo -e "${green}  Скрипт настройки сервера (aivisions)${plain}"
echo -e "${green}========================================${plain}\n"

# === Выбор режима ===
echo -e "${yellow}Что вы хотите сделать?${plain}"
echo -e "  ${green}1)${plain} Полная установка (подготовка сервера + Claude Code)"
echo -e "  ${green}2)${plain} Подготовка сервера"
echo -e "  ${green}3)${plain} Установка Claude Code"
while true; do
    read -u 3 -e -p "${read_yellow}Введите 1, 2 или 3 [по умолчанию 1]: ${read_plain}" MODE
    MODE=${MODE:-1}
    case $MODE in
        1 ) DO_IPV6=1; DO_PREP=1; DO_CLAUDE=1; DO_REBOOT=1; echo -e "${green}Режим: полная установка${plain}\n"; break ;;
        2 ) DO_IPV6=0; DO_PREP=1; DO_CLAUDE=0; DO_REBOOT=1; echo -e "${green}Режим: подготовка сервера${plain}\n"; break ;;
        3 ) DO_IPV6=1; DO_PREP=0; DO_CLAUDE=1; DO_REBOOT=0; echo -e "${green}Режим: установка Claude Code${plain}\n"; break ;;
        * ) echo -e "${red}Пожалуйста, введите 1, 2 или 3${plain}" ;;
    esac
done

# === Вопросы (только если выбрана подготовка сервера) ===
if [ "$DO_PREP" = "1" ]; then
    # 1. Название сервера (только латиница, цифры, дефис, точка)
    while true; do
        read -u 3 -e -p "${read_yellow}Введите название сервера: ${read_plain}" SERVER_NAME
        if [ -z "$SERVER_NAME" ]; then
            echo -e "${red}Ошибка: Название сервера обязательно!${plain}"
        elif printf '%s' "$SERVER_NAME" | LC_ALL=C grep -qE '[^a-zA-Z0-9.-]'; then
            echo -e "${red}Ошибка: только латиница, цифры, дефис и точка (без пробелов и кириллицы)!${plain}"
        elif printf '%s' "$SERVER_NAME" | grep -qE '^[.-]|[.-]$'; then
            echo -e "${red}Ошибка: не может начинаться или заканчиваться на дефис/точку!${plain}"
        else
            echo -e "${green}Название сервера: $SERVER_NAME${plain}"
            break
        fi
    done

    # 2. Порт SSH (число 1-65535)
    while true; do
        read -u 3 -e -p "${read_yellow}Введите порт SSH [по умолчанию 22022]: ${read_plain}" SSH_PORT
        SSH_PORT=${SSH_PORT:-22022}
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
            echo -e "${green}Порт SSH: $SSH_PORT${plain}"
            break
        else
            echo -e "${red}Ошибка: порт должен быть числом от 1 до 65535!${plain}"
        fi
    done

    # 3. Порты для UFW (каждый — число 1-65535)
    while true; do
        read -u 3 -e -p "${read_yellow}Введите порты для UFW через пробел [по умолчанию 80 443 $SSH_PORT]: ${read_plain}" UFW_PORTS
        UFW_PORTS=${UFW_PORTS:-"80 443 $SSH_PORT"}
        UFW_VALID=1
        for port in $UFW_PORTS; do
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                echo -e "${red}Ошибка: '$port' — некорректный порт (нужно число 1-65535)!${plain}"
                UFW_VALID=0
                break
            fi
        done
        if [ "$UFW_VALID" = "1" ]; then
            echo -e "${green}Порты UFW: $UFW_PORTS${plain}"
            break
        fi
    done

    # 4. Пароль для root (Enter — оставить текущий системный пароль без изменений)
    while true; do
        read -u 3 -s -p "${read_yellow}Введите новый пароль для root [Enter — оставить текущий]: ${read_plain}" ROOT_PASSWORD
        echo
        if [ -z "$ROOT_PASSWORD" ]; then
            PASSWORD_CHANGED=0
            echo -e "${green}Пароль root: оставлен текущий (без изменений)${plain}"
            break
        elif printf '%s' "$ROOT_PASSWORD" | LC_ALL=C grep -qE '[^!-~]'; then
            echo -e "${red}Ошибка: пароль — только латиница, цифры и символы (без пробелов и кириллицы)!${plain}"
        else
            PASSWORD_CHANGED=1
            echo -e "${green}Пароль root будет изменён${plain}"
            break
        fi
    done

    # 5. Обновления системы
    while true; do
        read -u 3 -e -p "${read_yellow}Установить обновления системы? [Y/n]: ${read_plain}" UPDATE_SYSTEM
        UPDATE_SYSTEM=${UPDATE_SYSTEM:-Y}
        case $UPDATE_SYSTEM in
            [Yy]* ) echo -e "${green}Обновления будут установлены${plain}"; break ;;
            [Nn]* ) echo -e "${yellow}Обновления будут пропущены${plain}"; break ;;
            * ) echo -e "${red}Пожалуйста, введите Y или n${plain}" ;;
        esac
    done
fi

echo -e "\n${green}========================================${plain}"
echo -e "${green}  Начало настройки${plain}"
echo -e "${green}========================================${plain}\n"

# === Отключение IPv6 (режимы 1 и 3 — обход блокировок IPv6, напр. Cloudflare) ===
if [ "$DO_IPV6" = "1" ]; then
    echo -e "${yellow}Отключение IPv6...${plain}"
    if [ -d /proc/sys/net/ipv6 ]; then
        cat > /etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
        sysctl -p /etc/sysctl.d/99-disable-ipv6.conf >/dev/null 2>&1 || true
        echo -e "${green}✓ IPv6 отключён${plain}\n"
    else
        echo -e "${green}✓ IPv6 уже отсутствует в системе — пропущено${plain}\n"
    fi
fi

# === Подготовка сервера (режимы 1 и 2) ===
if [ "$DO_PREP" = "1" ]; then

    # Обновление системы
    if [[ "$UPDATE_SYSTEM" =~ ^[Yy]$ ]]; then
        echo -e "${yellow}Обновление системы...${plain}"
        apt update && apt upgrade -y
        echo -e "${green}✓ Система обновлена${plain}\n"
    else
        echo -e "${yellow}Обновление системы пропущено${plain}\n"
    fi

    # Установка hostname
    echo -e "${yellow}Настройка hostname...${plain}"
    if grep -q "^127\.0\.0\.1" /etc/hosts; then
        sed -i "s/^127\.0\.0\.1.*/127.0.0.1 $SERVER_NAME/" /etc/hosts
    else
        echo "127.0.0.1 $SERVER_NAME" >> /etc/hosts
    fi
    # 127.0.1.1 (Yandex Cloud, Timeweb и другие cloud-провайдеры)
    if grep -q "^127\.0\.1\.1" /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $SERVER_NAME/" /etc/hosts
    fi
    # Отключить cloud-init перезапись /etc/hosts
    if [ -f /etc/cloud/cloud.cfg ]; then
        sed -i 's/manage_etc_hosts:.*/manage_etc_hosts: false/' /etc/cloud/cloud.cfg
        sed -i 's/^  - update_etc_hosts/  # - update_etc_hosts/' /etc/cloud/cloud.cfg
    fi
    hostnamectl set-hostname "$SERVER_NAME"
    echo -e "${green}✓ Hostname установлен: $SERVER_NAME${plain}\n"

    # Настройка SSH порта
    echo -e "${yellow}Настройка SSH порта...${plain}"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    mkdir -p /run/sshd
    if grep -q "^#Port" /etc/ssh/sshd_config; then
        sed -i "s/^#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    elif grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    fi
    sshd -t 2>/dev/null || echo -e "${yellow}Предупреждение: не удалось проверить конфигурацию SSH${plain}"
    if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
        echo -e "${green}✓ SSH порт установлен: $SSH_PORT${plain}"
        echo -e "${yellow}ВАЖНО: Убедитесь, что вы можете подключиться через новый порт ${SSH_PORT}!${plain}\n"
    else
        echo -e "${red}Ошибка: не удалось перезапустить SSH службу!${plain}"
        cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd
        exit 1
    fi

    # Настройка UFW
    echo -e "${yellow}Настройка UFW...${plain}"
    if ! command -v ufw &> /dev/null; then
        echo "UFW не установлен. Устанавливаем..."
        apt-get update
        apt-get install -y ufw
    fi
    ufw --force disable
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    for port in $UFW_PORTS; do
        ufw allow $port/tcp comment "Allowed by setup script"
        echo -e "${green}✓ Разрешен порт: $port${plain}"
    done
    ufw --force enable
    ufw reload
    echo -e "${green}✓ UFW настроен и перезапущен${plain}\n"

    # Настройка fail2ban
    echo -e "${yellow}Настройка fail2ban...${plain}"
    if ! command -v fail2ban-client &> /dev/null; then
        echo "fail2ban не установлен. Устанавливаем..."
        apt-get update
        apt-get install -y fail2ban
    fi
    cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled   = true
maxretry  = 3
findtime  = 1h
bantime   = 1d
ignoreip  = 127.0.0.1/8
port      = $SSH_PORT
EOF
    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl restart fail2ban
    echo -e "${green}✓ fail2ban настроен и запущен${plain}"
    echo -e "  - Порт SSH: ${SSH_PORT}"
    echo -e "  - Max Retry: 3"
    echo -e "  - Find Time: 1h"
    echo -e "  - Ban Time: 1d\n"

    # Смена пароля root (только если был введён новый)
    echo -e "${yellow}Настройка пароля root...${plain}"
    if [ "$PASSWORD_CHANGED" = "1" ]; then
        echo "root:$ROOT_PASSWORD" | chpasswd
        echo -e "${green}✓ Пароль root изменён${plain}\n"
    else
        echo -e "${green}✓ Пароль root оставлен текущий (без изменений)${plain}\n"
    fi

fi

# === Установка Claude Code (режимы 1 и 3) ===
if [ "$DO_CLAUDE" = "1" ]; then
    echo -e "${yellow}Установка Claude Code...${plain}"
    if curl -fsSL https://claude.ai/install.sh | bash; then
        # Глобальный симлинк в /usr/local/bin (уже в PATH) — claude работает сразу всем
        if [ -x "$HOME/.local/bin/claude" ]; then
            ln -sf "$HOME/.local/bin/claude" /usr/local/bin/claude
        fi
        # И в PATH через .bashrc/.profile — на случай обычного логина
        for rc in "$HOME/.bashrc" "$HOME/.profile"; do
            [ -f "$rc" ] || touch "$rc"
            grep -q 'HOME/.local/bin' "$rc" 2>/dev/null || \
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        done
        export PATH="$HOME/.local/bin:$PATH"
        # Автопроверка: команда реально работает?
        if command -v claude >/dev/null 2>&1 && CLAUDE_VER=$(claude --version 2>/dev/null); then
            echo -e "${green}✓ Claude Code установлен и доступен: ${plain}${CLAUDE_VER}${green} (запуск: ${plain}claude${green})${plain}\n"
        else
            echo -e "${yellow}⚠ Claude установлен, но не запустился по имени 'claude'.${plain}"
            echo -e "${yellow}  Запускайте полным путём: ${green}$HOME/.local/bin/claude${plain}\n"
        fi
    else
        echo -e "${red}✗ Ошибка установки Claude Code${plain}\n"
    fi
fi

# === Завершение ===
echo -e "${green}========================================${plain}"
echo -e "${green}  Настройка завершена успешно!${plain}"
echo -e "${green}========================================${plain}\n"

if [ "$DO_PREP" = "1" ]; then
    echo -e "${yellow}Параметры конфигурации:${plain}"
    echo -e "  Hostname: ${green}$SERVER_NAME${plain}"
    echo -e "  SSH порт: ${green}$SSH_PORT${plain}"
    echo -e "  UFW порты: ${green}$UFW_PORTS${plain}"
    echo -e "  fail2ban: ${green}активирован${plain}"
    if [ "$PASSWORD_CHANGED" = "1" ]; then
        echo -e "  Пароль root: ${green}изменён${plain}"
    else
        echo -e "  Пароль root: ${green}без изменений (текущий)${plain}"
    fi
    echo ""
fi

# === Предложение перезагрузки (режимы 1 и 2) ===
if [ "$DO_REBOOT" = "1" ]; then
    while true; do
        read -u 3 -e -p "${read_yellow}Перезагрузить систему сейчас? [Y/n]: ${read_plain}" REBOOT_NOW
        REBOOT_NOW=${REBOOT_NOW:-Y}
        case $REBOOT_NOW in
            [Yy]* )
                for i in 5 4 3 2 1; do
                    echo -ne "\r${yellow}Перезагрузка через $i...${plain}  "
                    sleep 1
                done
                echo -e "\r${green}Перезагрузка!            ${plain}"
                reboot
                break
                ;;
            [Nn]* )
                echo -e "${yellow}Перезагрузка отменена${plain}"
                echo -e "${yellow}Рекомендуется перезагрузить систему позже: ${green}sudo reboot${plain}"
                break
                ;;
            * )
                echo -e "${red}Пожалуйста, введите Y или n${plain}"
                ;;
        esac
    done
fi

# Закрываем file descriptor 3
exec 3<&-
