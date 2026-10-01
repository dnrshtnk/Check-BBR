#!/bin/bash

# ============================================
# BBR Check & Enable Script
# Проверяет статус BBR и включает его, если выключен
# ============================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка root прав
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Скрипт должен быть запущен от имени root (используйте sudo)"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Проверка и включение BBR            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка поддержки BBR ядром
KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)

if [ "$KERNEL_MAJOR" -lt 4 ] || { [ "$KERNEL_MAJOR" -eq 4 ] && [ "$KERNEL_MINOR" -lt 9 ]; }; then
    echo -e "${RED}[ERROR]${NC} Ядро $KERNEL_VERSION слишком старое. BBR требует ядро 4.9+"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Ядро: $KERNEL_VERSION (поддерживает BBR)"

# Проверка доступности модуля BBR
if ! modprobe tcp_bbr 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Не удалось загрузить модуль tcp_bbr (возможно уже встроен в ядро)"
else
    echo -e "${GREEN}[OK]${NC} Модуль tcp_bbr доступен"
fi

# Проверка текущего congestion control
CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
echo -e "${BLUE}[INFO]${NC} Текущий congestion control: ${YELLOW}$CURRENT_CC${NC}"

# Проверка статуса BBR
BBR_ENABLED=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null | grep -c "bbr" || true)

if [ "$BBR_ENABLED" -eq 1 ] && [ "$CURRENT_CC" = "bbr" ]; then
    echo -e "${GREEN}[OK]${NC} BBR уже включён и активен"
    
    # Проверка queueing discipline
    CURRENT_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")
    if [ "$CURRENT_QDISC" != "fq" ]; then
        echo -e "${YELLOW}[WARN]${NC} default_qdisc = $CURRENT_QDISC (рекомендуется fq)"
    else
        echo -e "${GREEN}[OK]${NC} Queueing discipline: fq"
    fi
    exit 0
fi

echo -e "${YELLOW}[INFO]${NC} BBR выключен. Включаем...${NC}"
echo ""

# Проверка доступных congestion control алгоритмов
AVAILABLE_CC=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "")
if ! echo "$AVAILABLE_CC" | grep -q "bbr"; then
    echo -e "${YELLOW}[WARN]${NC} BBR не найден в списке доступных алгоритмов"
    echo -e "${BLUE}[INFO]${NC} Доступные: $AVAILABLE_CC"
    echo -e "${BLUE}[INFO]${NC} Пытаемся загрузить модуль..."
    modprobe tcp_bbr 2>/dev/null || true
fi

# Резервная копия sysctl.conf
SYSCTL_CONF="/etc/sysctl.conf"
BACKUP_FILE="${SYSCTL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$SYSCTL_CONF" "$BACKUP_FILE" 2>/dev/null || touch "$SYSCTL_CONF"
echo -e "${GREEN}[OK]${NC} Резервная копия: $BACKUP_FILE"

# Удаляем старые записи BBR, если есть
sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"

# Добавляем настройки
{
    echo ""
    echo "# BBR settings (added by bbr-check script on $(date))"
    echo "net.core.default_qdisc = fq"
    echo "net.ipv4.tcp_congestion_control = bbr"
} >> "$SYSCTL_CONF"

echo -e "${GREEN}[OK]${NC} Настройки записаны в $SYSCTL_CONF"

# Применяем настройки немедленно
sysctl -w net.core.default_qdisc=fq >/dev/null
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null

# Применяем через sysctl -p (для надёжности)
sysctl -p >/dev/null 2>&1 || true

# Проверка результата
sleep 1
NEW_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
NEW_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")

echo ""
echo -e "${BLUE}========================================${NC}"
if [ "$NEW_CC" = "bbr" ]; then
    echo -e "${GREEN}✓ BBR успешно включён!${NC}"
    echo -e "${GREEN}  tcp_congestion_control = $NEW_CC${NC}"
    echo -e "${GREEN}  default_qdisc          = $NEW_QDISC${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}[NOTE]${NC} Настройки сохранены и применены. Перезагрузка не требуется."
    exit 0
else
    echo -e "${RED}✗ Не удалось включить BBR${NC}"
    echo -e "${RED}  Текущий congestion control: $NEW_CC${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}[HINT]${NC} Возможные причины:"
    echo "  - Ядро не поддерживает BBR (нужно 4.9+)"
    echo "  - Модуль tcp_bbr не загружен"
    echo "  - Виртуализация не поддерживает BBR"
    exit 1
fi