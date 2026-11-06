#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carga de biblioteca común
# shellcheck source=/dev/null
if [[ -f "${BASE_DIR}/lib/utils.sh" ]]; then
    source "${BASE_DIR}/lib/utils.sh"
else
    echo "ERROR: No se encontró la biblioteca ${BASE_DIR}/lib/utils.sh" >&2
    exit 1
fi

# Identificador único para aislar las tareas del proyecto en crontab
readonly CRON_TAG="# TAREA_MONITOREO_AUTOMATICO_SHELL"
readonly LOGS_DIR="${BASE_DIR}/reports"
readonly TARGET_SCRIPT="${BASE_DIR}/bin/01.sistema.sh"

show_help() {
    cat << EOF
Uso: $(basename "$0") [OPCIONES]

Módulo 4: Automatización y gestión interactiva de tareas en cron.
Permite programar, verificar, remover y simular ejecuciones automáticas de monitoreo.

Opciones de Línea de Comandos:
  -i, --install-daily <HH:MM>  Programa la ejecución diaria a la hora especificada.
  -s, --status                 Muestra el estado actual de las tareas en crontab.
  -r, --remove                 Remueve de forma limpia la tarea de crontab.
  -x, --run-now                Ejecuta el ciclo de monitoreo de inmediato (simulación).
  -h, --help                   Muestra esta ayuda y finaliza.

Sin argumentos: Inicia el asistente interactivo con menús guiados.
EOF
    exit 0
}

# ------------------------------------------------------------------------------
# 1. Verificación de Estado en Crontab
# ------------------------------------------------------------------------------
verificar_estado_cron() {
    print_separator
    echo -e "${COLOR_BOLD}--- ESTADO ACTUAL DE CRONTAB ---${COLOR_RESET}"

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null || true)

    if [[ -z "$crontab_content" ]]; then
        log_info "El usuario actual ($(whoami)) no tiene ninguna tarea programada en crontab."
        return 0
    fi

    if echo "$crontab_content" | grep -q "${CRON_TAG}"; then
        log_success "La tarea de monitoreo del proyecto se encuentra ACTIVA:"
        echo -e "${COLOR_GREEN}$(echo "$crontab_content" | grep -A 1 "${CRON_TAG}")${COLOR_RESET}"
    else
        log_warn "No hay ninguna tarea de monitoreo del proyecto registrada en crontab."
    fi

    echo ""
    echo -e "${COLOR_WHITE}Todas las tareas del usuario ($(whoami)):${COLOR_RESET}"
    crontab -l 2>/dev/null || echo "(Vacío)"
    print_separator
}

# ------------------------------------------------------------------------------
# 2. Eliminación Limpia y Segura de la Tarea Programada
# ------------------------------------------------------------------------------
remover_tarea_cron() {
    print_separator
    log_info "Iniciando proceso de desinstalación de la tarea de monitoreo en crontab..."

    local crontab_actual
    crontab_actual=$(crontab -l 2>/dev/null || true)

    if [[ -z "$crontab_actual" ]] || ! echo "$crontab_actual" | grep -q "${CRON_TAG}"; then
        log_info "No existe ninguna tarea de este proyecto en crontab para eliminar."
        return 0
    fi

    # Filtrar el crontab para eliminar la etiqueta y la línea de comando subsiguiente
    local nuevo_crontab
    nuevo_crontab=$(echo "$crontab_actual" | awk -v tag="${CRON_TAG}" '
        $0 ~ tag { skip=1; next }
        skip { skip=0; next }
        { print }
    ')

    if [[ -z "$nuevo_crontab" ]]; then
        # Si era la única tarea, limpiar crontab completamente
        crontab -r 2>/dev/null || true
    else
        echo "$nuevo_crontab" | crontab -
    fi

    log_success "La tarea de monitoreo fue removida exitosamente de crontab."
}

# ------------------------------------------------------------------------------
# 3. Instalación de la Tarea Programada
# ------------------------------------------------------------------------------
instalar_linea_cron() {
    local cron_schedule="$1"
    local descripcion="$2"

    ensure_directory_exists "$LOGS_DIR"

    # Comando a ejecutar: redirige stdout y stderr con fecha al log
    local comando_cron="bash \"${TARGET_SCRIPT}\" --quiet >> \"${LOGS_DIR}/monitoreo_\$(date +\\%Y\\%m\\%d).log\" 2>&1"
    local bloque_cron="${CRON_TAG} (${descripcion})
${cron_schedule} ${comando_cron}"

    # Primero remover si existía una versión previa
    local crontab_filtrado
    crontab_filtrado=$(crontab -l 2>/dev/null | awk -v tag="${CRON_TAG}" '
        $0 ~ tag { skip=1; next }
        skip { skip=0; next }
        { print }
    ' || true)

    # Inyectar la nueva tarea
    if [[ -z "$crontab_filtrado" ]]; then
        echo -e "${bloque_cron}" | crontab -
    else
        printf "%s\n%s\n" "$crontab_filtrado" "$bloque_cron" | crontab -
    fi

    log_success "Tarea programada instalada exitosamente en crontab:"
    echo -e "  ${COLOR_CYAN}Frecuencia :${COLOR_RESET} ${descripcion} (${cron_schedule})"
    echo -e "  ${COLOR_CYAN}Destino    :${COLOR_RESET} ${TARGET_SCRIPT}"
    echo -e "  ${COLOR_CYAN}Registro   :${COLOR_RESET} ${LOGS_DIR}/monitoreo_YYYYMMDD.log"
}

# ------------------------------------------------------------------------------
# 4. Asistente Interactivo de Configuración de Horarios
# ------------------------------------------------------------------------------
asistente_programacion() {
    print_separator
    echo -e "${COLOR_BOLD}--- ASISTENTE DE PROGRAMACIÓN CRON ---${COLOR_RESET}"
    echo "El asistente traducirá tus elecciones al formato de 5 campos de crontab:"
    echo "  1. Ejecución DIARIA a una hora fija (ej. a las 08:30 hrs)"
    echo "  2. Ejecución PERIÓDICA CADA N HORAS (ej. cada 2 o 4 horas)"
    echo "  3. Ejecución FRECUENTE CADA N MINUTOS (ej. cada 15 o 30 minutos)"
    echo "  4. Expresión personalizada avanzada de 5 campos (* * * * *)"
    echo -ne "${COLOR_YELLOW}Seleccione el tipo de programación [1-4]: ${COLOR_RESET}"
    read -r tipo_prog

    case "$tipo_prog" in
        1)
            echo -ne "${COLOR_YELLOW}Ingrese la hora (0-23): ${COLOR_RESET}"
            read -r hora
            echo -ne "${COLOR_YELLOW}Ingrese el minuto (0-59): ${COLOR_RESET}"
            read -r minuto

            if [[ ! "$hora" =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || [[ ! "$minuto" =~ ^([0-9]|[1-5][0-9])$ ]]; then
                log_error "Hora o minuto inválido. Ingrese valores dentro de los rangos válidos."
                return 1
            fi

            local cron_expr="${minuto} ${hora} * * *"
            instalar_linea_cron "$cron_expr" "Ejecución diaria a las $(printf '%02d:%02d' "$hora" "$minuto") hrs"
            ;;
        2)
            echo -ne "${COLOR_YELLOW}Ingrese el intervalo en horas (ej. 2, 4, 6): ${COLOR_RESET}"
            read -r cada_horas

            if [[ ! "$cada_horas" =~ ^[1-9]|1[0-9]|2[0-3]$ ]]; then
                log_error "Intervalo no válido."
                return 1
            fi

            local cron_expr="0 */${cada_horas} * * *"
            instalar_linea_cron "$cron_expr" "Ejecución periódica cada ${cada_horas} horas"
            ;;
        3)
            echo -ne "${COLOR_YELLOW}Ingrese el intervalo en minutos (ej. 10, 15, 30): ${COLOR_RESET}"
            read -r cada_mins

            if [[ ! "$cada_mins" =~ ^[1-9]|[1-5][0-9]$ ]]; then
                log_error "Minutos no válidos."
                return 1
            fi

            local cron_expr="*/${cada_mins} * * * *"
            instalar_linea_cron "$cron_expr" "Ejecución periódica cada ${cada_mins} minutos"
            ;;
        4)
            echo -ne "${COLOR_YELLOW}Ingrese los 5 campos de cron (ej. '0 12 * * 1-5'): ${COLOR_RESET}"
            read -r custom_cron
            if [[ -z "$custom_cron" ]]; then
                log_error "La expresión cron no puede estar vacía."
                return 1
            fi
            instalar_linea_cron "$custom_cron" "Programación personalizada manual"
            ;;
        *)
            log_error "Opción no válida."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 5. Ejecución Inmediata / Simulación
# ------------------------------------------------------------------------------
ejecutar_ciclo_inmediato() {
    print_separator
    log_info "Ejecutando ciclo de monitoreo inmediato (Simulación de tarea programada)..."
    ensure_directory_exists "$LOGS_DIR"

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local log_file="${LOGS_DIR}/monitoreo_${timestamp}.log"

    echo "================================================================================" >> "$log_file"
    echo "REGISTRO DE EJECUCIÓN PROGRAMADA - INICIO: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
    echo "================================================================================" >> "$log_file"

    # Redirección de stdout y stderr con operadores >> y 2>&1
    bash "${TARGET_SCRIPT}" >> "$log_file" 2>&1

    echo "--------------------------------------------------------------------------------" >> "$log_file"
    echo "REGISTRO DE EJECUCIÓN PROGRAMADA - FIN: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
    echo "================================================================================" >> "$log_file"

    log_success "Ciclo completado. Salida registrada en:"
    echo -e "  ${COLOR_CYAN}${log_file}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_WHITE}Últimas líneas del registro generado:${COLOR_RESET}"
    tail -n 12 "$log_file"
    print_separator
}

# ------------------------------------------------------------------------------
# Menú Principal Interactivo (while + case)
# ------------------------------------------------------------------------------
menu_interactivo() {
    local opt=""
    while true; do
        echo ""
        print_banner "MÓDULO 4: AUTOMATIZACIÓN Y ASISTENTE DE CRONTAB"
        echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} Programar nueva tarea de monitoreo (Asistente guiado)"
        echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} Ver estado y tareas activas en crontab"
        echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} Remover tarea de monitoreo de crontab (Desinstalación limpia)"
        echo -e "  ${COLOR_CYAN}4.${COLOR_RESET} Ejecutar monitoreo ahora mismo (Simulación con timestamp)"
        echo -e "  ${COLOR_CYAN}5.${COLOR_RESET} Salir"
        print_separator
        echo -ne "${COLOR_YELLOW}Seleccione una opción [1-5]: ${COLOR_RESET}"
        read -r opt

        case "$opt" in
            1)
                asistente_programacion
                ;;
            2)
                verificar_estado_cron
                ;;
            3)
                remover_tarea_cron
                ;;
            4)
                ejecutar_ciclo_inmediato
                ;;
            5)
                log_info "Saliendo del asistente de automatización."
                break
                ;;
            *)
                log_error "Opción '${opt}' no válida. Ingrese un valor entre 1 y 5."
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Punto de Entrada
# ------------------------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        menu_interactivo
    else
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -i|--install-daily)
                    local hora_param="$2"
                    local h="${hora_param%%:*}"
                    local m="${hora_param##*:}"
                    instalar_linea_cron "${m} ${h} * * *" "Ejecución diaria a las ${hora_param} hrs"
                    shift 2
                    ;;
                -s|--status)
                    verificar_estado_cron
                    shift
                    ;;
                -r|--remove)
                    remover_tarea_cron
                    shift
                    ;;
                -x|--run-now)
                    ejecutar_ciclo_inmediato
                    shift
                    ;;
                -h|--help)
                    show_help
                    ;;
                *)
                    log_error "Opción no reconocida: $1"
                    exit 1
                    ;;
            esac
        done
    fi
}

main "$@"
