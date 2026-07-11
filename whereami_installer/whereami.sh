#!/bin/sh
# whereami - универсальный определитель оболочки
# (c) 2026, your name

# Получаем PID текущего процесса
SHELL_PID=$$
SHELL_NAME="unknown"

# Определяем имя оболочки по нескольким методам

# 1. Проверяем переменные окружения
if [ -n "$BASH_VERSION" ]; then
    SHELL_NAME="bash"
    SHELL_VERSION="$BASH_VERSION"
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_NAME="zsh"
    SHELL_VERSION="$ZSH_VERSION"
elif [ -n "$FISH_VERSION" ]; then
    SHELL_NAME="fish"
    SHELL_VERSION="$FISH_VERSION"
elif [ -n "$KSH_VERSION" ]; then
    SHELL_NAME="ksh"
    SHELL_VERSION="$KSH_VERSION"
elif [ -n "$YASH_VERSION" ]; then
    SHELL_NAME="yash"
    SHELL_VERSION="$YASH_VERSION"
elif [ -n "$TCSH" ]; then
    SHELL_NAME="tcsh"
elif [ -n "$CSH" ]; then
    SHELL_NAME="csh"
else
    # 2. Пытаемся определить по имени процесса
    # Используем /proc/$$/exe если доступно (Linux)
    if [ -L "/proc/$$/exe" ]; then
        EXE_PATH=$(readlink -f "/proc/$$/exe" 2>/dev/null)
        EXE_NAME=$(basename "$EXE_PATH" 2>/dev/null)
        if [ -n "$EXE_NAME" ]; then
            case "$EXE_NAME" in
                bash|sh|dash|ash|zsh|fish|ksh|tcsh|csh|yash) SHELL_NAME="$EXE_NAME" ;;
                *) SHELL_NAME="($EXE_NAME)" ;;
            esac
        fi
    fi

    # 3. Альтернатива: ps
    if [ "$SHELL_NAME" = "unknown" ]; then
        EXE_NAME=$(ps -p $$ -o comm= 2>/dev/null)
        if [ -n "$EXE_NAME" ]; then
            case "$EXE_NAME" in
                bash|sh|dash|ash|zsh|fish|ksh|tcsh|csh|yash) SHELL_NAME="$EXE_NAME" ;;
                *) SHELL_NAME="($EXE_NAME)" ;;
            esac
        fi
    fi

    # 4. Проверяем $0
    if [ "$SHELL_NAME" = "unknown" ]; then
        EXE_NAME=$(basename "$0" 2>/dev/null)
        if [ -n "$EXE_NAME" ]; then
            SHELL_NAME="$EXE_NAME"
        fi
    fi
fi

# Если всё ещё неизвестно, пробуем определить по родительскому процессу
if [ "$SHELL_NAME" = "unknown" ]; then
    PARENT_PID=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    if [ -n "$PARENT_PID" ]; then
        PARENT_NAME=$(ps -p "$PARENT_PID" -o comm= 2>/dev/null)
        if [ -n "$PARENT_NAME" ]; then
            SHELL_NAME="$PARENT_NAME (parent)"
        fi
    fi
fi

# Вывод информации
echo "Shell: $SHELL_NAME"
[ -n "$SHELL_VERSION" ] && echo "Version: $SHELL_VERSION"
echo "PID: $SHELL_PID"
if [ -L "/proc/$$/exe" ]; then
    EXE_PATH=$(readlink -f "/proc/$$/exe" 2>/dev/null)
    [ -n "$EXE_PATH" ] && echo "Executable: $EXE_PATH"
else
    EXE_PATH=$(ps -p $$ -o args= 2>/dev/null | awk '{print $1}')
    [ -n "$EXE_PATH" ] && echo "Command: $EXE_PATH"
fi

# Дополнительно: проверяем, является ли оболочка интерактивной
case "$-" in
    *i*) echo "Interactive: yes" ;;
    *) echo "Interactive: no" ;;
esac

# Проверяем, есть ли доступ к history (простейшая проверка)
if type fc >/dev/null 2>&1 || type history >/dev/null 2>&1; then
    echo "History: available"
else
    echo "History: not available"
fi

