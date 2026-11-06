#!/usr/bin/env bash

set -euo pipefail

# Resolución de rutas relativas
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

# ------------------------------------------------------------------------------
# 1. Función para Crear Archivos o Directorios
# ------------------------------------------------------------------------------
crear_recurso() {
    print_separator
    echo -e "${COLOR_BOLD}--- CREAR ARCHIVO O DIRECTORIO ---${COLOR_RESET}"
    echo "1. Crear un Archivo de texto/prueba"
    echo "2. Crear un Directorio"
    echo -ne "${COLOR_YELLOW}Seleccione el tipo [1-2]: ${COLOR_RESET}"
    read -r tipo_recurso

    case "$tipo_recurso" in
        1)
            echo -ne "${COLOR_YELLOW}Ingrese la ruta/nombre del archivo a crear: ${COLOR_RESET}"
            read -r ruta_archivo
            if [[ -z "$ruta_archivo" ]]; then
                log_error "La ruta no puede estar vacía."
                return 1
            fi
            if [[ -e "$ruta_archivo" ]]; then
                log_warn "El recurso ya existe en: ${ruta_archivo}"
                if ! confirm_action "¿Desea actualizar su marca de tiempo (touch)?"; then
                    log_info "Operación cancelada por el usuario."
                    return 0
                fi
            fi
            # Asegurar directorio padre
            mkdir -p "$(dirname "$ruta_archivo")"
            touch "$ruta_archivo"
            log_success "Archivo creado correctamente en: ${ruta_archivo}"
            ;;
        2)
            echo -ne "${COLOR_YELLOW}Ingrese la ruta/nombre del directorio a crear: ${COLOR_RESET}"
            read -r ruta_directorio
            if [[ -z "$ruta_directorio" ]]; then
                log_error "La ruta del directorio no puede estar vacía."
                return 1
            fi
            if [[ -d "$ruta_directorio" ]]; then
                log_warn "El directorio ya existe: ${ruta_directorio}"
                return 0
            fi
            mkdir -p "$ruta_directorio"
            log_success "Directorio creado exitosamente: ${ruta_directorio}"
            ;;
        *)
            log_error "Opción inválida de creación."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# 2. Función para Copiar Archivos con Validación de Existencia
# ------------------------------------------------------------------------------
copiar_archivo() {
    print_separator
    echo -e "${COLOR_BOLD}--- COPIAR ARCHIVO ---${COLOR_RESET}"
    echo -ne "${COLOR_YELLOW}Ingrese la ruta del archivo origen: ${COLOR_RESET}"
    read -r origen

    # Validación de existencia y tipo de archivo origen
    if [[ -z "$origen" ]]; then
        log_error "La ruta de origen no puede estar vacía."
        return 1
    fi

    if [[ ! -f "$origen" ]]; then
        log_error "El archivo de origen no existe o no es un archivo regular: '${origen}'"
        return 1
    fi

    echo -ne "${COLOR_YELLOW}Ingrese la ruta o directorio destino: ${COLOR_RESET}"
    read -r destino

    if [[ -z "$destino" ]]; then
        log_error "La ruta de destino no puede estar vacía."
        return 1
    fi

    # Si el destino ya existe como archivo regular, solicitar confirmación
    if [[ -f "$destino" ]]; then
        log_warn "El archivo destino '${destino}' ya existe."
        if ! confirm_action "¿Desea sobrescribirlo?"; then
            log_info "Operación de copiado cancelada."
            return 0
        fi
    fi

    # Si el destino es un directorio que no existe, crear la ruta
    if [[ "$destino" == */ ]]; then
        mkdir -p "$destino"
    else
        mkdir -p "$(dirname "$destino")"
    fi

    cp -p "$origen" "$destino"
    log_success "Archivo copiado exitosamente de '${origen}' hacia '${destino}'"
}

# ------------------------------------------------------------------------------
# 3. Función para Cambiar Permisos a 644 o Modo Personalizado
# ------------------------------------------------------------------------------
cambiar_permisos() {
    print_separator
    echo -e "${COLOR_BOLD}--- CAMBIAR PERMISOS DE ARCHIVO ---${COLOR_RESET}"
    echo -ne "${COLOR_YELLOW}Ingrese la ruta del archivo a modificar: ${COLOR_RESET}"
    read -r archivo

    if [[ ! -e "$archivo" ]]; then
        log_error "El recurso '${archivo}' no existe."
        return 1
    fi

    echo "Permisos actuales de '${archivo}':"
    ls -ld "$archivo"

    echo ""
    echo "1. Asignar permisos estándar 644 (Lectura/Escritura propietario, Lectura grupo y otros)"
    echo "2. Asignar permisos ejecutables 755 (Lectura/Escritura/Ejecución propietario, Lectura/Ejecución otros)"
    echo "3. Ingresar permiso numérico octal personalizado (ej. 600, 700, 640)"
    echo -ne "${COLOR_YELLOW}Seleccione una opción [1-3]: ${COLOR_RESET}"
    read -r opt_perm

    local nuevo_permiso=""
    case "$opt_perm" in
        1)
            nuevo_permiso="644"
            ;;
        2)
            nuevo_permiso="755"
            ;;
        3)
            echo -ne "${COLOR_YELLOW}Ingrese la máscara octal de 3 dígitos (ej. 644): ${COLOR_RESET}"
            read -r nuevo_permiso
            # Validar que sea un número octal válido de 3 dígitos
            if [[ ! "$nuevo_permiso" =~ ^[0-7]{3}$ ]]; then
                log_error "Máscara octal no válida. Debe contener exactamente 3 dígitos del 0 al 7."
                return 1
            fi
            ;;
        *)
            log_error "Opción de permisos inválida."
            return 1
            ;;
    esac

    chmod "$nuevo_permiso" "$archivo"
    log_success "Permisos actualizados a ${nuevo_permiso} para '${archivo}'"
    echo "Verificación de permisos actualizados:"
    ls -ld "$archivo"
}

# ------------------------------------------------------------------------------
# 4. Función para Cambiar Propietario / Grupo (chown / chgrp)
# ------------------------------------------------------------------------------
cambiar_propietario() {
    print_separator
    echo -e "${COLOR_BOLD}--- CAMBIAR PROPIETARIO O GRUPO (chown / chgrp) ---${COLOR_RESET}"
    echo -ne "${COLOR_YELLOW}Ingrese la ruta del archivo o directorio: ${COLOR_RESET}"
    read -r objetivo

    if [[ ! -e "$objetivo" ]]; then
        log_error "El recurso '${objetivo}' no existe."
        return 1
    fi

    echo "Propietario y grupo actual:"
    ls -ld "$objetivo"

    echo ""
    echo -ne "${COLOR_YELLOW}Ingrese el nuevo usuario propietario (dejar vacío si no desea cambiar): ${COLOR_RESET}"
    read -r nuevo_user

    echo -ne "${COLOR_YELLOW}Ingrese el nuevo grupo (dejar vacío si no desea cambiar): ${COLOR_RESET}"
    read -r nuevo_grupo

    if [[ -z "$nuevo_user" && -z "$nuevo_grupo" ]]; then
        log_warn "No se especificó ni usuario ni grupo. Operación omitida."
        return 0
    fi

    # Comprobar si el usuario requiere privilegios de superusuario
    local chown_target=""
    if [[ -n "$nuevo_user" && -n "$nuevo_grupo" ]]; then
        chown_target="${nuevo_user}:${nuevo_grupo}"
    elif [[ -n "$nuevo_user" ]]; then
        chown_target="${nuevo_user}"
    else
        chown_target=":${nuevo_grupo}"
    fi

    log_info "Intentando aplicar 'chown ${chown_target} ${objetivo}'..."
    if chown "${chown_target}" "${objetivo}" 2>/dev/null; then
        log_success "Propietario/grupo modificado satisfactoriamente."
    else
        log_warn "Se requieren privilegios elevados para cambiar el propietario a otro usuario."
        if confirm_action "¿Desea intentar con sudo?"; then
            if sudo chown "${chown_target}" "${objetivo}"; then
                log_success "Propietario/grupo modificado con privilegios de superusuario."
            else
                log_error "No fue posible cambiar el propietario/grupo."
                return 1
            fi
        else
            log_info "Operación cancelada."
            return 0
        fi
    fi

    echo "Verificación final:"
    ls -ld "$objetivo"
}

# ------------------------------------------------------------------------------
# 5. Función de Eliminación Segura (Confirmación Directa y por Antigüedad/Fecha)
# ------------------------------------------------------------------------------
eliminar_archivos() {
    print_separator
    echo -e "${COLOR_BOLD}--- ELIMINACIÓN SEGURA DE ARCHIVOS ---${COLOR_RESET}"
    echo "1. Eliminar un archivo específico con confirmación previa"
    echo "2. Eliminar archivos temporales por fecha / antigüedad (días)"
    echo -ne "${COLOR_YELLOW}Seleccione el método [1-2]: ${COLOR_RESET}"
    read -r metodo_elim

    case "$metodo_elim" in
        1)
            echo -ne "${COLOR_YELLOW}Ingrese la ruta del archivo a eliminar: ${COLOR_RESET}"
            read -r archivo_a_borrar

            if [[ -z "$archivo_a_borrar" ]]; then
                log_error "La ruta no puede estar vacía."
                return 1
            fi

            if [[ ! -e "$archivo_a_borrar" ]]; then
                log_error "El archivo '${archivo_a_borrar}' no existe."
                return 1
            fi

            echo -e "${COLOR_RED}ADVERTENCIA: Esta acción eliminará permanentemente: '${archivo_a_borrar}'${COLOR_RESET}"
            if confirm_action "¿Está absolutamente seguro de proceder con la eliminación?"; then
                rm -rf "$archivo_a_borrar"
                log_success "Archivo '${archivo_a_borrar}' eliminado exitosamente."
            else
                log_info "Eliminación cancelada por el usuario."
            fi
            ;;
        2)
            echo -ne "${COLOR_YELLOW}Ingrese el directorio objetivo para la limpieza: ${COLOR_RESET}"
            read -r dir_limpieza

            if [[ ! -d "$dir_limpieza" ]]; then
                log_error "El directorio '${dir_limpieza}' no existe."
                return 1
            fi

            echo -ne "${COLOR_YELLOW}Ingrese la antigüedad mínima en días (ej. 7 para archivos de más de 7 días): ${COLOR_RESET}"
            read -r dias_antiguedad

            if [[ ! "$dias_antiguedad" =~ ^[0-9]+$ ]]; then
                log_error "Debe ingresar un número entero positivo de días."
                return 1
            fi

            log_info "Buscando archivos modificados hace más de ${dias_antiguedad} días en '${dir_limpieza}'..."
            mapfile -t archivos_encontrados < <(find "$dir_limpieza" -maxdepth 2 -type f -mtime +"$dias_antiguedad")

            if [[ ${#archivos_encontrados[@]} -eq 0 ]]; then
                log_info "No se encontraron archivos que superen los ${dias_antiguedad} días de antigüedad."
                return 0
            fi

            echo -e "${COLOR_CYAN}Archivos identificados para depuración (${#archivos_encontrados[@]}):${COLOR_RESET}"
            for arch in "${archivos_encontrados[@]}"; do
                echo "  - $arch"
            done

            if confirm_action "¿Confirma la eliminación de los ${#archivos_encontrados[@]} archivos listados?"; then
                for arch in "${archivos_encontrados[@]}"; do
                    rm -f "$arch"
                done
                log_success "Depuración completada exitosamente."
            else
                log_info "Operación de limpieza por fecha cancelada."
            fi
            ;;
        *)
            log_error "Opción de eliminación inválida."
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Bucle Principal del Menú Interactivo (while + case)
# ------------------------------------------------------------------------------
menu_principal() {
    local opcion=""

    while true; do
        echo ""
        print_banner "GESTOR EMPRESARIAL DE ARCHIVOS Y PERMISOS"
        echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} Crear archivo o directorio"
        echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} Copiar archivo con validación de existencia"
        echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} Cambiar permisos (644 / 755 / personalizado)"
        echo -e "  ${COLOR_CYAN}4.${COLOR_RESET} Cambiar propietario / grupo (chown / chgrp)"
        echo -e "  ${COLOR_CYAN}5.${COLOR_RESET} Eliminar archivos (con confirmación o por fecha/antigüedad)"
        echo -e "  ${COLOR_CYAN}6.${COLOR_RESET} Salir"
        print_separator
        echo -ne "${COLOR_YELLOW}Ingrese una opción [1-6]: ${COLOR_RESET}"
        read -r opcion

        case "$opcion" in
            1)
                crear_recurso
                ;;
            2)
                copiar_archivo
                ;;
            3)
                cambiar_permisos
                ;;
            4)
                cambiar_propietario
                ;;
            5)
                eliminar_archivos
                ;;
            6)
                log_info "Finalizando sesión del gestor de archivos. ¡Hasta luego!"
                break
                ;;
            *)
                # Blindaje ante opciones fuera de rango o caracteres no válidos
                log_error "Opción '${opcion}' no válida. Debe seleccionar un número del 1 al 6."
                ;;
        esac
    done
}

menu_principal "$@"
