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

# Rutas de datos y reportes por defecto
DATA_FILE="${BASE_DIR}/data/servidores.txt"
REPORTS_DIR="${BASE_DIR}/reports"
REPORT_ALERTS="${REPORTS_DIR}/servidores_alertados.txt"
REPORT_MODIFIED="${REPORTS_DIR}/servidores_modificados.txt"
THRESHOLD=70

show_help() {
    cat << EOF
Uso: $(basename "$0") [OPCIONES]

Módulo 3: Análisis de métricas con Awk y Sed.
Procesa el archivo de uso de disco de servidores, filtra excesos y reemplaza estados.

Opciones:
  -i, --input <RUTA>       Ruta del archivo de datos a analizar.
                           (Por defecto: ${DATA_FILE})
  -t, --threshold <NUM>    Porcentaje umbral de uso de disco para alertas.
                           (Por defecto: ${THRESHOLD}%)
  -h, --help               Muestra esta ayuda y finaliza.

Ejemplos:
  $(basename "$0")
  $(basename "$0") --threshold 80
  $(basename "$0") -i /ruta/otro_dataset.txt
EOF
    exit 0
}

# Procesamiento de parámetros CLI
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            DATA_FILE="$2"
            shift 2
            ;;
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Opción no reconocida: $1"
            echo "Consulte '$0 --help' para ver la sintaxis."
            exit 1
            ;;
    esac
done

validar_entorno() {
    # 1. Validación de existencia del archivo de entrada
    if [[ ! -f "$DATA_FILE" ]]; then
        log_error "No existe el archivo de datos: '${DATA_FILE}'"
        log_info "Asegúrese de proveer un archivo con formato: SERVIDOR IP USO_DISCO ESTADO"
        exit 1
    fi

    # 2. Asegurar existencia del directorio de reportes
    ensure_directory_exists "$REPORTS_DIR"
}

procesar_con_awk() {
    log_info "Iniciando análisis de ocupación con AWK (Umbral de alerta > ${THRESHOLD}%)..."

    # Encabezado del reporte de alertas
    cat << EOF > "$REPORT_ALERTS"
================================================================================
          REPORTE DE SERVIDORES CON ALERTA DE ALMACENAMIENTO (> ${THRESHOLD}%)
================================================================================
Fecha de Análisis : $(date '+%Y-%m-%d %H:%M:%S')
Archivo Origen    : ${DATA_FILE}
Umbral Definido   : ${THRESHOLD}% de uso de disco
--------------------------------------------------------------------------------
SERVIDOR                 IP               USO_DISCO(%)   ESTADO_ORIGINAL
--------------------------------------------------------------------------------
EOF

    # Ejecución de AWK para filtrar y calcular métricas
    awk -v umbral="$THRESHOLD" '
        BEGIN {
            count_total = 0;
            count_alert = 0;
            sum_disk = 0;
        }
        # Omitir comentarios y líneas en blanco
        /^#/ || NF == 0 { next; }

        {
            count_total++;
            servidor = $1;
            ip = $2;
            uso = $3 + 0; # Asegurar tipo numérico
            estado = $4;

            if (uso > umbral) {
                count_alert++;
                sum_disk += uso;
                # Imprimir en formato columnar alineado
                printf "%-24s %-16s %-14d %-15s\n", servidor, ip, uso, estado;
            }
        }

        END {
            print "--------------------------------------------------------------------------------";
            printf "Total Servidores Analizados : %d\n", count_total;
            printf "Servidores que Superan %d%%  : %d\n", umbral, count_alert;
            if (count_alert > 0) {
                printf "Promedio de Ocupación Alerta: %.2f%%\n", (sum_disk / count_alert);
            }
            print "================================================================================";
        }
    ' "$DATA_FILE" >> "$REPORT_ALERTS"

    # Mostrar en consola exactamente el resultado formateado
    cat "$REPORT_ALERTS"
}

procesar_con_sed() {
    log_info "Iniciando sustitución semántica con SED sobre réplica segura..."

    # Crear réplica para preservar los datos de origen (principio de inmutabilidad)
    cp "$DATA_FILE" "$REPORT_MODIFIED"

    # Reemplazos de normalización semántica de estados:
    # 1. 'normal' -> 'revisado'
    # 2. 'critico' -> 'alerta'
    # Con inserción de comentario de procesamiento en la cabecera
    sed -i 's/\bnormal\b/revisado/g; s/\bcritico\b/alerta/g' "$REPORT_MODIFIED"
    sed -i "1i # [PROCESADO CON SED] Fecha: $(date '+%Y-%m-%d %H:%M:%S') | Estados actualizados: 'normal' a 'revisado' y 'critico' a 'alerta'" "$REPORT_MODIFIED"

    log_success "Transformación completada con SED."
}

resumen_ejecucion() {
    local total_alertados
    total_alertados=$(awk -v umbral="$THRESHOLD" '!/^#/ && NF > 0 && ($3+0) > umbral {count++} END {print count+0}' "$DATA_FILE")

    print_separator
    log_success "Análisis finalizado con total concordancia entre pantalla y archivos:"
    echo -e "  ${COLOR_CYAN}1. Reporte de Alertas (AWK)  :${COLOR_RESET} ${REPORT_ALERTS}"
    echo -e "     -> Servidores filtrados (> ${THRESHOLD}%): ${COLOR_BOLD}${total_alertados}${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}2. Dataset Modificado (SED) :${COLOR_RESET} ${REPORT_MODIFIED}"
    echo -e "     -> Estados actualizados: 'normal' a 'revisado' y 'critico' a 'alerta'"
    print_separator
}

main() {
    print_banner "MÓDULO 3: ANÁLISIS DE INFORMACIÓN (AWK & SED)"
    validar_entorno
    procesar_con_awk
    procesar_con_sed
    resumen_ejecucion
}

main "$@"
