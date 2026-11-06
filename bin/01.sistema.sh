#!/usr/bin/env bash

set -euo pipefail

# Resolución de rutas relativas al script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Carga de utilidades compartidas
# shellcheck source=/dev/null
if [[ -f "${BASE_DIR}/lib/utils.sh" ]]; then
    source "${BASE_DIR}/lib/utils.sh"
else
    echo "ERROR: No se encontró la biblioteca ${BASE_DIR}/lib/utils.sh" >&2
    exit 1
fi

# Variables de configuración por defecto
REPORTS_DIR="${BASE_DIR}/reports"
DEFAULT_OUTPUT="${REPORTS_DIR}/reporte_sistema.txt"
OUTPUT_FILE="${DEFAULT_OUTPUT}"
QUIET_MODE=false

# Umbrales corporativos de monitoreo
readonly THRESHOLD_WARN=80
readonly THRESHOLD_CRIT=95

show_help() {
    cat << EOF
Uso: $(basename "$0") [OPCIONES]

Módulo 1: Monitoreo integral del sistema empresarial.
Recopila usuario, fecha, SO, almacenamiento raíz, memoria RAM y CPU.

Opciones:
  -o, --output <RUTA>   Especifica la ruta del archivo de reporte.
                        (Por defecto: ${DEFAULT_OUTPUT})
  -q, --quiet           Modo silencioso. No imprime en consola, solo genera reporte.
  -h, --help            Muestra esta ayuda y finaliza.

Ejemplos:
  $(basename "$0")
  $(basename "$0") -o /tmp/mi_reporte.txt
  $(basename "$0") --quiet
EOF
    exit 0
}

# Procesamiento de argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Opción desconocida: $1"
            echo "Use '$0 --help' para ver las opciones disponibles."
            exit 1
            ;;
    esac
done

# Función para calcular etiqueta de umbral
get_threshold_badge() {
    local val_int="$1"
    if (( val_int >= THRESHOLD_CRIT )); then
        echo "CRÍTICO (> ${THRESHOLD_CRIT}%)"
    elif (( val_int >= THRESHOLD_WARN )); then
        echo "ALERTA (> ${THRESHOLD_WARN}%)"
    else
        echo "NORMAL (< ${THRESHOLD_WARN}%)"
    fi
}

# Obtención de Métricas
collect_metrics() {
    # 1. Usuario actual
    CURRENT_USER=$(whoami)

    # 2. Fecha y hora sincronizada
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    # 3. Distribución Linux limpia (PRETTY_NAME de /etc/os-release)
    OS_DISTRO=$(get_os_pretty_name)

    # 4. Almacenamiento: Exclusivamente partición raíz (/) para descartar montajes volátiles
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    DISK_PERCENT_STR=$(df -h / | awk 'NR==2 {print $5}')
    DISK_PERCENT_INT="${DISK_PERCENT_STR//%/}"
    DISK_STATUS=$(get_threshold_badge "$DISK_PERCENT_INT")

    # 5. Memoria RAM del SO (monitoreo exclusivo de memoria física sin swap)
    # Extraído directamente de /proc/meminfo para portabilidad total
    MEM_TOTAL_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    MEM_AVAIL_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    MEM_USED_KB=$(( MEM_TOTAL_KB - MEM_AVAIL_KB ))

    MEM_TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
    MEM_USED_MB=$(( MEM_USED_KB / 1024 ))
    MEM_AVAIL_MB=$(( MEM_AVAIL_KB / 1024 ))
    MEM_PERCENT_INT=$(( (MEM_USED_KB * 100) / MEM_TOTAL_KB ))
    MEM_STATUS=$(get_threshold_badge "$MEM_PERCENT_INT")

    # 6. Uso de CPU (cálculo de carga en porcentaje vía /proc/stat)
    CPU_USAGE=$(awk '/^cpu / {usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}' /proc/stat)
    CPU_INT=${CPU_USAGE%.*}
    CPU_STATUS=$(get_threshold_badge "$CPU_INT")
}

# Generación del contenido del reporte
generate_report_text() {
    cat << EOF
================================================================================
                    REPORTE DE ESTADO DEL SISTEMA SERVIDOR
================================================================================
Fecha y Hora de Generación : ${CURRENT_DATE}
Usuario de Ejecución       : ${CURRENT_USER}
Sistema Operativo          : ${OS_DISTRO}
--------------------------------------------------------------------------------
1. MONITOREO DE ALMACENAMIENTO (Partición Raíz '/')
   - Espacio Total         : ${DISK_TOTAL}
   - Espacio Ocupado       : ${DISK_USED} (${DISK_PERCENT_STR})
   - Espacio Disponible    : ${DISK_AVAIL}
   - Estado del Disco      : ${DISK_STATUS}

2. MONITOREO DE MEMORIA RAM (Exclusivo Sistema Operativo)
   - Memoria Total         : ${MEM_TOTAL_MB} MB
   - Memoria en Uso        : ${MEM_USED_MB} MB (${MEM_PERCENT_INT}%)
   - Memoria Disponible    : ${MEM_AVAIL_MB} MB
   - Estado de la Memoria  : ${MEM_STATUS}

3. MONITOREO DE PROCESAMIENTO (CPU)
   - Uso Actual de CPU     : ${CPU_USAGE}%
   - Estado del CPU        : ${CPU_STATUS}
--------------------------------------------------------------------------------
Leyenda de Umbrales: NORMAL (< 80%) | ALERTA (>= 80%) | CRÍTICO (>= 95%)
================================================================================
EOF
}

main() {
    collect_metrics

    # Preparar directorio de reporte
    local target_dir
    target_dir="$(dirname "${OUTPUT_FILE}")"
    ensure_directory_exists "${target_dir}"

    # Escribir reporte a archivo de texto plano
    local report_content
    report_content=$(generate_report_text)
    echo "${report_content}" > "${OUTPUT_FILE}"


    # Imprimir en consola si no está en modo silencioso
    if [[ "${QUIET_MODE}" == false ]]; then
        print_banner "MONITOREO DE SISTEMA - REPORTE EJECUTIVO"
        echo -e "${COLOR_CYAN}Usuario Activo        :${COLOR_RESET} ${CURRENT_USER}"
        echo -e "${COLOR_CYAN}Fecha y Hora          :${COLOR_RESET} ${CURRENT_DATE}"
        echo -e "${COLOR_CYAN}Distribución Linux    :${COLOR_RESET} ${COLOR_BOLD}${OS_DISTRO}${COLOR_RESET}"
        print_separator
        echo -e "${COLOR_WHITE}Almacenamiento Raíz (/):${COLOR_RESET} Total ${DISK_TOTAL} | Usado ${DISK_USED} (${DISK_PERCENT_STR}) -> [${DISK_STATUS}]"
        echo -e "${COLOR_WHITE}Memoria RAM (SO)      :${COLOR_RESET} Total ${MEM_TOTAL_MB}MB | Usada ${MEM_USED_MB}MB (${MEM_PERCENT_INT}%) -> [${MEM_STATUS}]"
        echo -e "${COLOR_WHITE}Uso de CPU            :${COLOR_RESET} ${CPU_USAGE}% -> [${CPU_STATUS}]"
        print_separator
        log_success "Reporte exportado exitosamente a: ${OUTPUT_FILE}"
    fi
}

main "$@"
