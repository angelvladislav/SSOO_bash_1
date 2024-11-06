#!/bin/bash

mostrar_ayuda() {
    echo "Uso: infosession.sh [-h] [-z] [-u user1 ...] [-d dir]"
    echo ""
    echo "Opciones:"
    echo "  -h              Muestra esta ayuda y termina."
    echo "  -e              Muestra la tabla de procesos."
    echo "  -z              Muestra también los procesos con identificador de sesión 0."
    echo "  -u user1 ...    Muestra los procesos de los usuarios especificados."
    echo "  -d dir          Muestra procesos abiertos en un directorio especificado."
    echo "  -t              Los procesos seleccionados tendrán que tener fozosamente una termnal asociada."
    exit 0
}

if ! command -v ps &>/dev/null || ! command -v awk &>/dev/null; then
    echo "Error: se necesitan los comandos 'ps' y 'awk' para ejecutar este script."
    exit 1
fi

mostrar_sesion_0=false
mostrar_tabla_procesos=false
usuario_actual=()
directorio_actual=""
con_terminal=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h)
            mostrar_ayuda
            ;;
        -e)
            mostrar_tabla_procesos=true
            shift
            ;;
        -z)
            mostrar_sesion_0=true
            shift
            ;;
        -u)
            shift
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
            shift
            if [[ "$#" -eq 0 || "$1" == -* ]]; then
                echo "Error: La opción -d requiere un directorio."
                exit 1
            fi
            directorio_actual="$1"
            shift
            ;;
        -t)
            con_terminal=true
            shift 
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
echo "Mostrar procesos: $mostrar_tabla_procesos"

pids_directorio=() 
if [[ -n "$directorio_actual" ]]; then
    mapfile -t pids_directorio < <(lsof +d "$directorio_actual" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
    if [[ ${#pids_directorio[@]} -eq 0 ]]; then
        echo "No se encontraron procesos con archivos abiertos en el directorio especificado."
        exit 0
    fi
fi

mostrar_procesos() {
    printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    echo "-------------------------------------------------------------------------"

    usuarios_regex=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_regex" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) pids_set[pids_array[pid]]
        }
        NR > 1{
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n", $1, $2, $3, $4, $5, $6, $7
            }
        }
    ' | sort -k4,4
}

mostrar_sesiones() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "PID_LIDER" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_regex=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_regex" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) pids_set[pids_array[pid]]
        }
        NR > 1{
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                procesos[$1]["grupos"][$2]++
                if (!procesos[$1]["lider"]) {
                    procesos[$1]["lider_pid"] = $1
                    procesos[$1]["lider_user"] = $4
                    procesos[$1]["lider_tty"] = $5
                    procesos[$1]["lider_cmd"] = $6
                }
            }
        }
        END {
            for (sid in procesos) {
                lider_pid = procesos[sid]["lider_pid"] ? procesos[sid]["lider_pid"] : "?"
                lider_user = procesos[sid]["lider_user"] ? procesos[sid]["lider_user"] : "?"
                lider_tty = procesos[sid]["lider_tty"] ? procesos[sid]["lider_tty"] : "?"
                lider_cmd = procesos[sid]["lider_cmd"] ? procesos[sid]["lider_cmd"] : "?"
                grupos = length(procesos[sid]["grupos"])

                printf "%-10s %-10d %-10s %-15s %-10s %s\n", sid, grupos, lider_pid, lider_user, lider_tty, lider_cmd
            }
        }
    ' | sort -k4,4
}

if [[ "$mostrar_tabla_procesos" == true ]]; then 
    mostrar_procesos
else 
    mostrar_sesiones
fi
