#!/bin/bash

# Función para mostrar la ayuda
mostrar_ayuda() {
    echo "Uso: infosession.sh [-h] [-z] [-u user1 ...] [-d dir]"
    echo ""
    echo "Opciones:"
    echo "  -h        Muestra esta ayuda y termina."
    echo "  -z        Muestra también los procesos con identificador de sesión 0."
    echo "  -u user1 ...   Muestra los procesos de los usuarios especificados."
    echo "  -d dir Muestra procesos abiertos en un directorio especificado."
    exit 0
}

# Comprobación de herramientas necesarias
if ! command -v ps &>/dev/null || ! command -v awk &>/dev/null; then
    echo "Error: se necesitan los comandos 'ps' y 'awk' para ejecutar este script."
    exit 1
fi

# Variables iniciales
mostrar_sesion_0=false
usuario_actual=()
directorio_actual=""

# Manejo de opciones
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h)
            mostrar_ayuda
            ;;
        -z)
            mostrar_sesion_0=true
            shift
            ;;
        -u)
            shift
            # Asegurar que al menos un usuario se especifique
            if [[ "$#" -eq 0 || "$1" == -* ]]; then
                echo "Error: La opción -u requiere al menos un usuario."
                exit 1
            fi
            while [[ "$#" -gt 0 && "$1" != -* ]]; do
                usuarios+=("$1")
                shift
            done
            ;;
        -d)
            directorio_actual="$2"
            shift 2
            ;;
        *)
            echo "Error: Opción no válida"
            exit 1
            ;;
    esac
done


echo "Usuarios especificados: ${usuarios[*]}"
echo "Directorio especificado: $directorio_actual"
echo "Mostrar sesión 0: $mostrar_sesion_0"

pids_directorio=()
if [[ -n "$directorio_actual" ]]; then
    mapfile -t pids_directorio < <(lsof +d "$directorio_actual" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
    if [[ ${#pids_directorio[@]} -eq 0 ]]; then
        echo "No se encontraron procesos con archivos abiertos en el directorio especificado."
        exit 0
    fi
fi

# Función para filtrar y mostrar la tabla de procesos
mostrar_procesos() {
    printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    echo "-------------------------------------------------------------------------"

    usuarios_regex=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_regex" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) pids_set[pids_array[pid]]
        }
        {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)

            if (usuario_valido && pid_valido && sesion_valida) {
                printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n", $1, $2, $3, $4, $5, $6, $7
            }
        }
    ' | sort -t ' ' -k4
}



# Ejecución del script
mostrar_procesos
