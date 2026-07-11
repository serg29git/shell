#!/bin/sh
# whereami - universal shell detector

# Получаем вывод ps -p $$ -o comm=
ps_output=$(ps -p $$ -o comm= 2>&1)

# Если ps выдал 'fish: $$ is not the pid...' — это fish
if echo "$ps_output" | grep -q "fish: $$ is not the pid"; then
    shell_name="fish"
    shell_pid="$fish_pid"
else
    # Иначе берём имя из ps
    shell_cmd=$(echo "$ps_output" | head -n1)
    if [ -n "$shell_cmd" ]; then
        shell_name="$shell_cmd"
    else
        # fallback по переменным
        if [ -n "$BASH_VERSION" ]; then
            shell_name="bash"
        elif [ -n "$ZSH_VERSION" ]; then
            shell_name="zsh"
        elif [ -n "$FISH_VERSION" ]; then
            shell_name="fish"
        elif [ -n "$KSH_VERSION" ]; then
            shell_name="ksh"
        elif [ -n "$YASH_VERSION" ]; then
            shell_name="yash"
        else
            shell_name="unknown"
        fi
    fi
    shell_pid=$$
fi

# --- Вывод ---
echo "Shell: $shell_name"

# Версия
case "$shell_name" in
    bash)   [ -n "$BASH_VERSION" ] && echo "Version: $BASH_VERSION" ;;
    zsh)    [ -n "$ZSH_VERSION" ] && echo "Version: $ZSH_VERSION" ;;
    fish)   [ -n "$FISH_VERSION" ] && echo "Version: $FISH_VERSION" ;;
    ksh)    [ -n "$KSH_VERSION" ] && echo "Version: $KSH_VERSION" ;;
    yash)   [ -n "$YASH_VERSION" ] && echo "Version: $YASH_VERSION" ;;
esac

echo "PID: $shell_pid"

# Путь к исполняемому файлу
if [ -L "/proc/$$/exe" ]; then
    exe_path=$(readlink -f "/proc/$$/exe" 2>/dev/null)
    [ -n "$exe_path" ] && echo "Executable: $exe_path"
else
    exe_path=$(ps -p "$shell_pid" -o args= 2>/dev/null | awk '{print $1}')
    [ -n "$exe_path" ] && echo "Command: $exe_path"
fi

# История (проверяем, доступна ли)
if history 2>/dev/null | tail -n 10 >/dev/null 2>&1; then
    echo "History: available"
else
    echo "History: not supported"
fi
