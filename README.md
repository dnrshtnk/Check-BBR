# BBR Check & Enable Script

Скрипт для автоматической проверки и включения **BBR** (Bottleneck Bandwidth and Round-trip propagation time) — алгоритма контроля перегрузки TCP от Google, который значительно ускоряет сетевое соединение на VPS.

## 📋 Что делает скрипт

- ✅ Проверяет наличие root-прав
- ✅ Проверяет версию ядра (требуется 4.9+)
- ✅ Загружает модуль `tcp_bbr`
- ✅ Проверяет текущий статус BBR
- ✅ **Если BBR выключен** — включает его и сообщает об этом
- ✅ **Если BBR уже включён** — просто информирует
- ✅ Создаёт резервную копию `/etc/sysctl.conf` перед изменениями
- ✅ Применяет настройки без перезагрузки

## 🚀 Быстрый запуск

### Вариант 1: Одна команда через curl

<code>
curl -fsSL https://raw.githubusercontent.com/dnrshtnk/main/bbr-check.sh | sudo bash
</code>

### Вариант 2: Одна команда через wget

<code>
wget -qO- https://raw.githubusercontent.com/dnrshtnk/main/bbr-check.sh | sudo bash
</code>

### Вариант 3: Скачать и запустить

<code>
curl -fsSL https://raw.githubusercontent.com/dnrshtnk/main/bbr-check.sh -o bbr-check.sh
</code>

<code>
chmod +x bbr-check.sh
</code>

<code>
sudo ./bbr-check.sh
</code>

## 📖 Использование

### Проверить статус BBR вручную

<code>
sysctl net.ipv4.tcp_congestion_control
</code>

Если вывод содержит `bbr` — значит BBR уже включён:

<code>
net.ipv4.tcp_congestion_control = bbr
</code>

### Проверить очередь (qdisc)

<code>
sysctl net.core.default_qdisc
</code>

Рекомендуемое значение:

<code>
net.core.default_qdisc = fq
</code>

## 🔍 Пример вывода скрипта

### Если BBR выключен

<code>
========================================
   Проверка и включение BBR
========================================
[OK] Ядро: 5.15 (поддерживает BBR)
[OK] Модуль tcp_bbr доступен
[INFO] Текущий congestion control: cubic
[INFO] BBR выключен. Включаем...
[OK] Резервная копия: /etc/sysctl.conf.backup.20250101_120000
[OK] Настройки записаны в /etc/sysctl.conf
========================================
✓ BBR успешно включён!
  tcp_congestion_control = bbr
  default_qdisc          = fq
========================================
</code>

### Если BBR уже включён

<code>
========================================
   Проверка и включение BBR
========================================
[OK] Ядро: 5.15 (поддерживает BBR)
[OK] Модуль tcp_bbr доступен
[INFO] Текущий congestion control: bbr
[OK] BBR уже включён и активен
[OK] Queueing discipline: fq
</code>

## ⚙️ Что изменяется в системе

Скрипт добавляет в `/etc/sysctl.conf` следующие строки:

<code>
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
</code>

Перед изменениями автоматически создаётся резервная копия:

<code>
/etc/sysctl.conf.backup.YYYYMMDD_HHMMSS
</code>

## 🔧 Требования

| Требование | Значение |
|-----------|----------|
| ОС | Linux (Ubuntu, Debian, CentOS, AlmaLinux, Rocky и др.) |
| Ядро | 4.9 или новее |
| Права | root (или sudo) |
| Виртуализация | KVM, VMware, Hyper-V, Bare Metal |

> ⚠️ **Важно:** на OpenVZ и LXC BBR может не работать, так как ядро общее с хост-системой.

## 🛠 Восстановление из бэкапа

Если что-то пошло не так, восстановите исходный конфиг:

<code>
sudo cp /etc/sysctl.conf.backup.YYYYMMDD_HHMMSS /etc/sysctl.conf
</code>

<code>
sudo sysctl -p
</code>

## ❓ FAQ

### Как проверить, что BBR действительно работает?

Выполните:

<code>
sysctl net.ipv4.tcp_congestion_control
</code>

Должно быть `bbr`.

Дополнительно можно проверить активные соединения:

<code>
ss -tin | grep bbr
</code>

### Нужна ли перезагрузка после включения?

Нет, настройки применяются на лету через `sysctl -w`.

### Почему BBR не включается на OpenVZ?

На OpenVZ/LXC используется общее ядро с хост-системой, и модуль `tcp_bbr` может быть недоступен. Решение — перейти на KVM VPS.

### Безопасно ли это?

Да. BBR — официальный алгоритм из ядра Linux с 4.9. Он используется по умолчанию в Google Cloud и многих крупных сервисах.

## 📄 Лицензия

MIT — используйте свободно.

## 🤝 Вклад

Pull requests приветствуются. Если нашли баг — создайте issue.