#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Paleta de Colores ANSI para Salida en Terminal
# ------------------------------------------------------------------------------
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_MAGENTA="\033[1;35m"
readonly COLOR_CYAN="\033[1;36m"
readonly COLOR_WHITE="\033[1;37m"

# ------------------------------------------------------------------------------
# Funciones de Logging y Notificaciones
# ------------------------------------------------------------------------------
log_info() {
    local mensaje="$1"
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - ${mensaje}"
}

log_success() {
    local mensaje="$1"
    echo -e "${COLOR_GREEN}[ÉXITO]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - ${mensaje}"
}

log_warn() {
    local mensaje="$1"
    echo -e "${COLOR_YELLOW}[ALERTA]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - ${mensaje}"
}

log_error() {
    local mensaje="$1"
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - ${mensaje}" >&2
}

# ------------------------------------------------------------------------------
# Separadores Visuales y Encabezados
# ------------------------------------------------------------------------------
print_banner() {
    local titulo="$1"
    echo -e "${COLOR_BLUE}================================================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_WHITE}  ${titulo}${COLOR_RESET}"
    echo -e "${COLOR_BLUE}================================================================================${COLOR_RESET}"
}

print_separator() {
    echo -e "${COLOR_BLUE}--------------------------------------------------------------------------------${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Validación y Entrada de Usuario
# ------------------------------------------------------------------------------
confirm_action() {
    local pregunta="${1:-¿Desea continuar con esta acción?}"
    local respuesta

    while true; do
        echo -ne "${COLOR_YELLOW}${pregunta} [s/N]: ${COLOR_RESET}"
        read -r respuesta
        # Convertir a minúsculas
        respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')
        case "$respuesta" in
            s|si|sí|y|yes)
                return 0
                ;;
            n|no|"" )
                return 1
                ;;
            *)
                echo -e "${COLOR_RED}Respuesta no válida. Ingrese 's' para Sí o 'n' para No.${COLOR_RESET}"
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Validación de Rutas y Directorios
# ------------------------------------------------------------------------------
ensure_directory_exists() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path" || {
            log_error "No se pudo crear el directorio: ${dir_path}"
            return 1
        }
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Detección del Sistema Operativo Limpio y Estandarizado
# ------------------------------------------------------------------------------
get_os_pretty_name() {
    if [[ -f /etc/os-release ]]; then
        # Extraer el valor de PRETTY_NAME sin comillas
        grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"'
    else
        uname -srm
    fi
}
