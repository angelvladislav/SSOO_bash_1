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
    echo "  -t              Los procesos seleccionados tendrán que tener forzosamente una termnal asociada."
    echo "  -sm             Las tablas se ordenaran por memoria."
    echo "  -sg             Las tablas se ordenaran por grupos (incompatible con -e)."
    echo "  -r              Las tablas se ordenaran reversivamente."
    exit 0
}

if ! command -v ps &>/dev/null || ! command -v awk &>/dev/null; then
    echo "Error: se necesitan los comandos 'ps' y 'awk' para ejecutar este script."
    exit 1
fi

mostrar_sesion_0=false
mostrar_tabla_procesos=false
con_terminal=false
mostrar_tabla_memoria=false
mostrar_tabla_grupos=false
mostrar_tabla_reversa=false
usuario_actual=()
directorio_actual=""

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
        -sm)
            mostrar_tabla_memoria=true
            shift
            ;;
        -sg)
            mostrar_tabla_grupos=true
            shift
            ;;
        -r)
            mostrar_tabla_reversa=true
            shift
            ;;
        *)
            echo "Error: Opción no válida"
            exit 1
            ;;
    esac
done

echo " "
echo "TABLA DE VARIABLES"
echo "Usuarios especificados: ${usuarios[*]}"
echo "Directorio especificado: $directorio_actual"
echo "Mostrar sesión 0: $mostrar_sesion_0"
echo "Mostrar procesos: $mostrar_tabla_procesos"
echo "Mostrar terminal: $con_terminal"
echo "Mostrar tabla segun la memoria: $mostrar_tabla_memoria"
echo "Mostrar tabla segun grupos: $mostrar_tabla_grupos"
echo "Mostrar tabla reversa: $mostrar_tabla_reversa"
echo " "

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

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {       # pids_array es un array simple: pids_array[1] = "123"
                pids_set[pids_array[pid]]   # pids_set es un array asociativo: pids_set["123"] = 1
            }
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
    ' | sort -k4,4 -f
}

mostrar_procesos_reversa() {
    printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    echo "-------------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
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
    ' | sort -r -k4,4 -f 
}

mostrar_procesos_memoria() {
    printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    echo "-------------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
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
    ' | sort -n -k6,6
}

mostrar_procesos_memoria_reversa() {
    printf "%-10s %-10s %-10s %-15s %-10s %-10s %s\n" "SID" "PGID" "PID" "USER" "TTY" "%MEM" "CMD"
    echo "-------------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | tr -s ' ' | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
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
    ' | sort -r -n -k6,6
}

mostrar_sesiones() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -k4,4 -f
}




mostrar_sesiones_reversa() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -r -k4,4 -f 
}

mostrar_sesiones_memoria() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -k3,3
}

mostrar_sesiones_memoria_reversa() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -r -k3,3
}

mostrar_sesiones_grupos() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -n -k2,2
}

mostrar_sesiones_grupos_reversa() {
    printf "%-10s %-10s %-10s %-15s %-10s %s\n" "SID" "GRUPOS" "%MEM_TOTAL" "USER_LIDER" "TTY" "CMD"
    echo "---------------------------------------------------------------------"

    usuarios_especificados=$(IFS="|"; echo "${usuarios[*]}")

    ps -eo sid,pgid,pid,euser,tty,%mem,cmd | awk -v mostrar_sesion_0="$mostrar_sesion_0" -v usuarios="$usuarios_especificados" -v pids="$(IFS="|"; echo "${pids_directorio[*]}")" -v con_terminal="$con_terminal" '
        BEGIN {
            split(pids, pids_array, "|")
            for (pid in pids_array) {
                pids_set[pids_array[pid]]
            }
        }
        NR > 1 {
            usuario_valido = ($4 ~ usuarios || usuarios == "")
            pid_valido = ($3 in pids_set || length(pids_set) == 0)
            sesion_valida = (mostrar_sesion_0 == "true" || $1 != 0)
            terminal_valida = (con_terminal == "false" || $5 != "?")

            if (usuario_valido && pid_valido && sesion_valida && terminal_valida) {
                sid = $1
                pgid = $2
                clave_grupo = sid "_" pgid

                # Incrementar el contador de grupos únicos por SID
                if (!(clave_grupo in grupos_por_sid_unicos)) {
                    grupos_por_sid[sid]++
                    grupos_por_sid_unicos[clave_grupo] = 1
                }

                # Acumular la memoria total para el SID
                mem_total[sid] += $6

                # Registrar los datos del líder solo si aún no se ha asignado
                if (!(sid in lider_user)) {
                    lider_user[sid] = $4
                    lider_tty[sid] = $5
                    lider_cmd[sid] = $7
                }
            }
        }
        END {
            for (sid in grupos_por_sid) {
                # Valores predeterminados para campos no definidos
                mem_total_val = (mem_total[sid] ? mem_total[sid] : "?")
                lider_user_val = (lider_user[sid] ? lider_user[sid] : "?")
                lider_tty_val = (lider_tty[sid] ? lider_tty[sid] : "?")
                lider_cmd_val = (lider_cmd[sid] ? lider_cmd[sid] : "?")
                grupos_totales = grupos_por_sid[sid]

                printf "%-10s %-10d %-10.2f %-15s %-10s %s\n", sid, grupos_totales, mem_total_val, lider_user_val, lider_tty_val, lider_cmd_val
            }
        }
    ' | sort -r -n -k2,2
}


if [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == false ]]; then 
    mostrar_procesos_memoria
elif [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == true ]]; then
    mostrar_procesos_memoria_reversa
elif [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == false ]]; then
    mostrar_procesos
elif [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == true ]]; then
    mostrar_procesos_reversa
elif [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == true ]]; then
    echo "la opción -sm y la opcion -sg no son compatibles entre si"
    exit 1
elif [[ "$mostrar_tabla_procesos" == true && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == true ]]; then
    echo "La opción -e y la opción -sg no son compatibles entre si"
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == false ]]; then
    mostrar_sesiones_memoria
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == true ]]; then
    mostrar_sesiones_memoria_reversa
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == true && "$mostrar_tabla_grupos" == true ]]; then
    echo "la opción -sm y la opcion -sg no son compatibles entre si"
    exit 1
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == true && "$mostrar_tabla_reversa" == false ]]; then
    mostrar_sesiones_grupos
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == true && "$mostrar_tabla_reversa" == true ]]; then
    mostrar_sesiones_grupos_reversa
elif [[ "$mostrar_tabla_procesos" == false && "$mostrar_tabla_memoria" == false && "$mostrar_tabla_grupos" == false && "$mostrar_tabla_reversa" == true ]]; then
    mostrar_sesiones_reversa
else
    mostrar_sesiones
fi