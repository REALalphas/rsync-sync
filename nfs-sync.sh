#!/bin/bash

# Функция для проверки наличия установленной утилиты
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "Утилита $1 не установлена. Установите ее с помощью вашего менеджера пакетов."
        exit 1
    fi
}

# Функция для запроса пути с проверкой существования
get_valid_path() {
    local prompt="$1"
    local path
    read -p "$prompt" path
    if [ ! -d "$path" ]; then
        echo "Папка не существует. Убедитесь, что путь указан правильно."
        exit 1
    fi
    echo "$path"
}

# ПРОГЕРСС-БАР НЕ РАБОТАЕТ.
# Функция для синхронизации с использованием pv (прогресс-бара) и/или проверки контрольной суммы
sync_with_pv_and_checksum() {
    local source_path="$1"
    local target_path="$2"
    local use_pv="$3"
    local use_checksum="$4"

    local rsync_options="-avz"
    if [[ $use_checksum == [Yy] ]]; then
        rsync_options="$rsync_options --checksum"
    fi

    if [[ $use_pv == [Yy] ]]; then
        rsync $rsync_options "$source_path" | pv -W -s $(du -sb "$source_path" | awk '{print $1}') | (rsync -aivz --progress "$source_path" "$target_path" && echo "Transfer completed.")
    else
        rsync $rsync_options "$source_path" "$target_path"
    fi
}

# Проверка установленных утилит
check_tool rsync
check_tool gio

# Запрос пути к исходной папке
source_path=$(get_valid_path "Введите путь к исходной папке: ")

# Запрос пути к целевой папке на NFS
read -p "Введите путь к целевой папке на NFS: " target_path

# Проверка, начинается ли путь с префикса nfs://
if [[ "$target_path" == nfs://* ]]; then
    # Использование gio для пути с префиксом nfs://
    target_local_path=$(gio info "$target_path" | grep "local path:" | awk '{print $3}')
    echo "Итоговый целевой путь: $target_local_path"
else
    # В противном случае, использование пути как есть
    target_local_path="$target_path"
fi

# Проверка, что локальный путь существует
if [ -z "$target_local_path" ] || [ ! -d "$target_local_path" ]; then
    echo "Локальный путь к целевой папке на NFS не существует. Убедитесь, что путь указан правильно."
    exit 1
fi

# Проверка наличия установленного pv (Pipe Viewer)
check_tool pv

# Вопрос о использовании pv (с вариантом "y" по умолчанию)
read -p "Использовать pv для отображения прогресс-бара? [Y/n] " use_pv
use_pv=${use_pv:-y} # Устанавливаем "y" по умолчанию

# Вопрос о проверке контрольной суммы (с вариантом "n" по умолчанию)
read -p "Выполнить проверку контрольной суммы при синхронизации? [y/N] " use_checksum
use_checksum=${use_checksum:-n} # Устанавливаем "n" по умолчанию

# Вызов функции для синхронизации с учетом выбора пользователя
sync_with_pv_and_checksum "$source_path" "$target_local_path" "$use_pv" "$use_checksum"

# Завершение скрипта
echo "Синхронизация завершена."
