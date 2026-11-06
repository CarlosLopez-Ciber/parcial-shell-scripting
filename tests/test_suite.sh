#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_DIR}/lib/utils.sh"

AUDIT_REPORT="${BASE_DIR}/reports/qa_audit_report.txt"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local nombre="$1"
    local comando="$2"
    TOTAL_TESTS=$(( TOTAL_TESTS + 1 ))

    echo -ne "  [TEST ${TOTAL_TESTS}] ${nombre}... "
    if eval "$comando" >/dev/null 2>&1; then
        echo -e "${COLOR_GREEN}APROBADO${COLOR_RESET}"
        PASSED_TESTS=$(( PASSED_TESTS + 1 ))
        echo "  [OK] Test ${TOTAL_TESTS}: ${nombre}" >> "$AUDIT_REPORT"
    else
        echo -e "${COLOR_RED}FALLÓ${COLOR_RESET}"
        FAILED_TESTS=$(( FAILED_TESTS + 1 ))
        echo "  [FAIL] Test ${TOTAL_TESTS}: ${nombre}" >> "$AUDIT_REPORT"
    fi
}

main() {
    print_banner "SUITE DE PRUEBAS AUTOMATIZADAS Y CONTROL DE CALIDAD"
    log_info "Iniciando batería de pruebas unitarias y de integración..."

    ensure_directory_exists "$(dirname "$AUDIT_REPORT")"
    cat << EOF > "$AUDIT_REPORT"
================================================================================
           INFORME DE AUDITORÍA Y CONTROL DE CALIDAD (QA TEST SUITE)
================================================================================
Fecha de Auditoría: $(date '+%Y-%m-%d %H:%M:%S')
Sistema Operativo : $(get_os_pretty_name)
Usuario Auditor   : $(whoami)
================================================================================
EOF

    echo -e "\n${COLOR_BOLD}--- BLOQUE 1: VALIDACIÓN SINTÁCTICA Y PERMISOS ---${COLOR_RESET}"
    run_test "Sintaxis limpia de lib/utils.sh (bash -n)" "bash -n '${BASE_DIR}/lib/utils.sh'"
    run_test "Sintaxis limpia de bin/01.sistema.sh" "bash -n '${BASE_DIR}/bin/01.sistema.sh'"
    run_test "Sintaxis limpia de bin/02.gestor.sh" "bash -n '${BASE_DIR}/bin/02.gestor.sh'"
    run_test "Sintaxis limpia de bin/03.analisis.sh" "bash -n '${BASE_DIR}/bin/03.analisis.sh'"
    run_test "Sintaxis limpia de bin/04.automatizacion.sh" "bash -n '${BASE_DIR}/bin/04.automatizacion.sh'"
    run_test "Permisos de ejecución en todos los scripts de bin/" "[[ -x '${BASE_DIR}/bin/01.sistema.sh' && -x '${BASE_DIR}/bin/02.gestor.sh' && -x '${BASE_DIR}/bin/03.analisis.sh' && -x '${BASE_DIR}/bin/04.automatizacion.sh' ]]"

    echo -e "\n${COLOR_BOLD}--- BLOQUE 2: MÓDULO 1 (01.sistema.sh) ---${COLOR_RESET}"
    run_test "Ejecución exitosa de 01.sistema.sh (Exit code 0)" "'${BASE_DIR}/bin/01.sistema.sh' --quiet"
    run_test "Generación del reporte físico (reporte_sistema.txt)" "[[ -s '${BASE_DIR}/reports/reporte_sistema.txt' ]]"
    run_test "Presencia de parámetros requeridos (Usuario, SO, Raíz, RAM, CPU)" "grep -q 'Usuario de Ejecución' '${BASE_DIR}/reports/reporte_sistema.txt' && grep -q 'MONITOREO DE ALMACENAMIENTO' '${BASE_DIR}/reports/reporte_sistema.txt' && grep -q 'MONITOREO DE MEMORIA RAM' '${BASE_DIR}/reports/reporte_sistema.txt' && grep -q 'MONITOREO DE PROCESAMIENTO' '${BASE_DIR}/reports/reporte_sistema.txt'"
    run_test "Presencia de umbrales evaluativos en el reporte" "grep -q 'Leyenda de Umbrales: NORMAL' '${BASE_DIR}/reports/reporte_sistema.txt'"

    echo -e "\n${COLOR_BOLD}--- BLOQUE 3: MÓDULO 2 (02.gestor.sh) ---${COLOR_RESET}"
    local tmp_file="/tmp/qa_prueba_gestor_$$.txt"
    local tmp_copy="/tmp/qa_copia_gestor_$$.txt"
    run_test "Creación de archivo mediante flujo de 02.gestor.sh" "printf '1\n1\n%s\n6\n' '${tmp_file}' | '${BASE_DIR}/bin/02.gestor.sh' && [[ -f '${tmp_file}' ]]"
    run_test "Asignación de permisos 644 y verificación física" "printf '3\n%s\n1\n6\n' '${tmp_file}' | '${BASE_DIR}/bin/02.gestor.sh' && [[ \$(stat -c %a '${tmp_file}') == '644' ]]"
    run_test "Copiado de archivo con validación de existencia" "printf '2\n%s\n%s\n6\n' '${tmp_file}' '${tmp_copy}' | '${BASE_DIR}/bin/02.gestor.sh' && [[ -f '${tmp_copy}' ]]"
    run_test "Resiliencia ante entradas no válidas (Opción 99 no rompe el script)" "printf '99\n6\n' | '${BASE_DIR}/bin/02.gestor.sh'"
    run_test "Eliminación con confirmación" "printf '5\n1\n%s\ns\n6\n' '${tmp_file}' | '${BASE_DIR}/bin/02.gestor.sh' && [[ ! -e '${tmp_file}' ]]"
    rm -f "$tmp_copy"

    echo -e "\n${COLOR_BOLD}--- BLOQUE 4: MÓDULO 3 (03.analisis.sh - AWK & SED) ---${COLOR_RESET}"
    run_test "Existencia y consistencia de dataset servidores.txt" "[[ -s '${BASE_DIR}/data/servidores.txt' ]] && grep -q 'srv-' '${BASE_DIR}/data/servidores.txt'"
    run_test "Ejecución exitosa de 03.analisis.sh" "'${BASE_DIR}/bin/03.analisis.sh'"
    run_test "Reporte AWK generado correctamente (servidores_alertados.txt)" "[[ -s '${BASE_DIR}/reports/servidores_alertados.txt' ]] && grep -q 'REPORTE DE SERVIDORES CON ALERTA' '${BASE_DIR}/reports/servidores_alertados.txt'"
    run_test "Filtrado exacto de servidores > 70% con awk" "grep -q 'srv-bd-prod01' '${BASE_DIR}/reports/servidores_alertados.txt' && grep -q 'srv-mail-postfix' '${BASE_DIR}/reports/servidores_alertados.txt'"
    run_test "Dataset transformado con SED (estados revisado y alerta)" "[[ -s '${BASE_DIR}/reports/servidores_modificados.txt' ]] && grep -q 'alerta' '${BASE_DIR}/reports/servidores_modificados.txt' && grep -q 'revisado' '${BASE_DIR}/reports/servidores_modificados.txt'"
    run_test "Manejo de error controlado ante archivo inexistente (Exit code 1)" "! '${BASE_DIR}/bin/03.analisis.sh' -i '/ruta/falsa/inexistente.txt'"

    echo -e "\n${COLOR_BOLD}--- BLOQUE 5: MÓDULO 4 (04.automatizacion.sh - CRON) ---${COLOR_RESET}"
    run_test "Ejecución inmediata (--run-now) y generación de log fechado" "'${BASE_DIR}/bin/04.automatizacion.sh' --run-now && ls ${BASE_DIR}/reports/monitoreo_*.log"
    run_test "Instalación idempotente en crontab (--install-daily 08:00)" "'${BASE_DIR}/bin/04.automatizacion.sh' --install-daily 08:00 && crontab -l | grep -q 'TAREA_MONITOREO_AUTOMATICO_SHELL'"
    run_test "Verificación de estado (--status)" "'${BASE_DIR}/bin/04.automatizacion.sh' --status"
    run_test "Remoción limpia de crontab (--remove)" "'${BASE_DIR}/bin/04.automatizacion.sh' --remove && ! crontab -l 2>/dev/null | grep -q 'TAREA_MONITOREO_AUTOMATICO_SHELL'"

    echo "" >> "$AUDIT_REPORT"
    echo "================================================================================" >> "$AUDIT_REPORT"
    printf "TOTAL DE PRUEBAS : %d\nAPROBADAS        : %d\nFALLIDAS         : %d\n" "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS" >> "$AUDIT_REPORT"
    echo "ESTADO FINAL     : $( (( FAILED_TESTS == 0 )) && echo 'SOBRESALIENTE (100% PASS)' || echo 'REQUIERE ATENCIÓN' )" >> "$AUDIT_REPORT"
    echo "================================================================================" >> "$AUDIT_REPORT"

    print_separator
    echo -e "${COLOR_BOLD}RESULTADOS DE LA AUDITORÍA DE CALIDAD:${COLOR_RESET}"
    echo -e "  Total de pruebas ejecutadas : ${TOTAL_TESTS}"
    echo -e "  Pruebas APROBADAS           : ${COLOR_GREEN}${PASSED_TESTS}${COLOR_RESET}"
    echo -e "  Pruebas FALLIDAS            : ${COLOR_RED}${FAILED_TESTS}${COLOR_RESET}"
    print_separator

    if (( FAILED_TESTS == 0 )); then
        log_success "¡AUDITORÍA COMPLETADA EXITOSAMENTE!"
        log_info "Evidencia documentada en: ${AUDIT_REPORT}"
        return 0
    else
        log_error "Se encontraron fallas en la batería de pruebas."
        return 1
    fi
}

main "$@"
