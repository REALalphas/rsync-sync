#!/bin/bash

# Check system locale and set language accordingly
if [[ "$LANG" == "ru"* ]]; then
    # Russian language
    PROMPT_TOOL_NOT_INSTALLED="Утилита %s не установлена. Установите ее с помощью вашего менеджера пакетов."
    PROMPT_FOLDER_NOT_EXIST="Папка не существует. Убедитесь, что путь указан правильно."
    PROMPT_ENTER_SOURCE_FOLDER="Введите путь к исходной папке: "
    PROMPT_ENTER_TARGET_FOLDER="Введите путь к целевой папке на NFS: "
    PROMPT_USE_PV="Использовать pv для отображения прогресс-бара? [Y/n] "
    PROMPT_USE_CHECKSUM="Выполнить проверку контрольной суммы при синхронизации? [y/N] "
    MESSAGE_TARGET_PATH="Итоговый целевой путь: %s"
    MESSAGE_TARGET_PATH_NOT_EXIST="Локальный путь к целевой папке на NFS не существует. Убедитесь, что путь указан правильно."
    MESSAGE_SYNC_COMPLETED="Синхронизация завершена."
else
    # English language (default)
    PROMPT_TOOL_NOT_INSTALLED="Utility %s is not installed. Please install it using your package manager."
    PROMPT_FOLDER_NOT_EXIST="Folder does not exist. Make sure the path is correct."
    PROMPT_ENTER_SOURCE_FOLDER="Enter the path to the source folder: "
    PROMPT_ENTER_TARGET_FOLDER="Enter the path to the target folder on NFS: "
    PROMPT_USE_PV="Use pv to display the progress bar? [Y/n] "
    PROMPT_USE_CHECKSUM="Perform checksum verification during synchronization? [y/N] "
    MESSAGE_TARGET_PATH="Final target path: %s"
    MESSAGE_TARGET_PATH_NOT_EXIST="The local path to the NFS target folder does not exist. Make sure the path is correct."
    MESSAGE_SYNC_COMPLETED="Synchronization completed."
fi

# Function to check the presence of an installed tool
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        printf "$PROMPT_TOOL_NOT_INSTALLED" "$1"
        exit 1
    fi
}

# Function to request a path with existence check
get_valid_path() {
    local prompt="$1"
    local path
    read -p "$prompt" path
    if [ ! -d "$path" ]; then
        printf "$PROMPT_FOLDER_NOT_EXIST"
        exit 1
    fi
    echo "$path"
}

# PROGRESS BAR IS NOT WORKING.
# Function for synchronization using pv (progress bar) and/or checksum verification
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
        rsync $rsync_options "$source_path" | pv -W -s $(du -sb "$source_path" | awk '{print $1}') | (rsync -aivz --progress "$source_path" "$target_path" && echo "$MESSAGE_SYNC_COMPLETED")
    else
        rsync $rsync_options "$source_path" "$target_path"
    fi
}

# Check for installed utilities
check_tool rsync
check_tool gio

# Request the path to the source folder
source_path=$(get_valid_path "$PROMPT_ENTER_SOURCE_FOLDER")

# Request the path to the target folder on NFS
read -p "$PROMPT_ENTER_TARGET_FOLDER" target_path

# Check if the path starts with the nfs:// prefix
if [[ "$target_path" == nfs://* ]]; then
    # Use gio for paths with the nfs:// prefix
    target_local_path=$(gio info "$target_path" | grep "local path:" | awk '{print $3}')
    printf "$MESSAGE_TARGET_PATH" "$target_local_path"
else
    # Otherwise, use the path as is
    target_local_path="$target_path"
fi

# Check that the local path exists
if [ -z "$target_local_path" ] || [ ! -d "$target_local_path" ]; then
    echo "$MESSAGE_TARGET_PATH_NOT_EXIST"
    exit 1
fi

# Check for the presence of installed pv (Pipe Viewer)
check_tool pv

# Ask whether to use pv (with "y" as the default option)
read -p "$PROMPT_USE_PV" use_pv
use_pv=${use_pv:-y} # Set "y" as the default option

# Ask whether to perform checksum verification (with "n" as the default option)
read -p "$PROMPT_USE_CHECKSUM" use_checksum
use_checksum=${use_checksum:-n} # Set "n" as the default option

# Call the function for synchronization based on user choices
sync_with_pv_and_checksum "$source_path" "$target_local_path" "$use_pv" "$use_checksum"

# Script completion
echo "$MESSAGE_SYNC_COMPLETED"
