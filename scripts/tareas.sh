
#!/bin/bash
# ==========================================================
# SCRIPT 4: PROGRAMADOR DE TAREAS AUTOMATICAS CON CRON
# ==========================================================

# 1. RUTAS
BASE="$HOME/proyecto_bash"
DIR_SCRIPTS="$BASE/scripts"
DIR_LOGS="$BASE/logs"

ETIQUETA="#GESTOR-TAREAS"

mkdir -p "$DIR_LOGS"

# 2. COLORES Y MENSAJES
VERDE=$'\033[0;32m'
AMARILLO=$'\033[1;33m'
ROJO=$'\033[0;31m'
AZUL=$'\033[0;36m'
NC=$'\033[0m'

ok() {
    echo "${VERDE}[OK]${NC} $1"
}

error() {
    echo "${ROJO}[X]${NC} $1"
}

aviso() {
    echo "${AMARILLO}[!]${NC} $1"
}

# Verificar instalacion de cron
command -v crontab >/dev/null || {
    error "Cron no esta instalado. Ejecuta: sudo apt install cron"
    exit 1
}

# Verificar servicio cron
if ! systemctl is-active --quiet cron; then
    aviso "El servicio cron no esta activo."
    sudo systemctl start cron || exit 1
fi

DIAS=(Domingo Lunes Martes Miercoles Jueves Viernes Sabado Domingo)

MESES=("" Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)

DIAS_MES=(0 31 29 31 30 31 30 31 31 30 31 30 31)

# 3. VALIDAR NUMEROS
pedir_numero() {
    local v

    while true; do
        read -rp "$1 ($2-$3): " v

        if [[ "$v" =~ ^[0-9]+$ ]] &&
           (( 10#$v >= $2 && 10#$v <= $3 )); then
            NUM=$((10#$v))
            return
        fi

        error "Valor no valido. Escribe un numero entre $2 y $3."
    done
}

# 4. TRADUCIR CODIGO CRON A LENGUAJE SENCILLO
traducir() {
    local mi="$1"
    local ho="$2"
    local di="$3"
    local me="$4"
    local ds="$5"
    local n='^[0-9]+$'
    local hh

    if [[ "$mi" == "*" && "$ho" == "*" &&
          "$di" == "*" && "$me" == "*" && "$ds" == "*" ]]; then

        echo "Cada minuto"

    elif [[ "$mi" =~ ^\*/([0-9]+)$ &&
            "$ho" == "*" && "$di" == "*" &&
            "$me" == "*" && "$ds" == "*" ]]; then

        echo "Cada ${BASH_REMATCH[1]} minutos"

    elif [[ "$mi" =~ $n && "$ho" == "*" &&
            "$di" == "*" && "$me" == "*" && "$ds" == "*" ]]; then

        echo "Cada hora, en el minuto $mi"

    elif [[ "$mi" =~ $n && "$ho" =~ $n ]]; then

        hh=$(printf '%02d:%02d' "$((10#$ho))" "$((10#$mi))")

        if [[ "$di" == "*" && "$me" == "*" && "$ds" == "*" ]]; then
            echo "Todos los dias a las $hh"

        elif [[ "$di" == "*" && "$me" == "*" && "$ds" =~ $n ]]; then
            echo "Cada ${DIAS[$ds]} a las $hh"

        elif [[ "$di" =~ $n && "$me" == "*" && "$ds" == "*" ]]; then
            echo "El dia $di de cada mes a las $hh"

        elif [[ "$di" =~ $n && "$me" =~ $n && "$ds" == "*" ]]; then
            echo "Cada $di de ${MESES[$((10#$me))]} a las $hh"

        else
            echo "Personalizada ($mi $ho $di $me $ds)"
        fi

    else
        echo "Personalizada ($mi $ho $di $me $ds)"
    fi
}

# 5. CARGAR TAREAS CREADAS POR EL PROGRAMA
cargar_tareas() {
    mapfile -t TAREAS < <(
        crontab -l 2>/dev/null | grep -F "$ETIQUETA"
    )
}

# ==========================================================
# OPCION 1: VER TAREAS PROGRAMADAS
# ==========================================================

ver_tareas() {
    cargar_tareas

    echo
    echo "================ TAREAS PROGRAMADAS ================"

    if [[ ${#TAREAS[@]} -eq 0 ]]; then
        aviso "No hay tareas programadas todavia."
        return 1
    fi

    printf "%-4s | %-25s | %-34s | %-15s\n" \
        "N" "NOMBRE" "CUANDO SE EJECUTA" "CODIGO CRON"

    echo "--------------------------------------------------------------------------"

    local i mi ho di me ds resto nombre

    for i in "${!TAREAS[@]}"; do
        read -r mi ho di me ds resto <<< "${TAREAS[$i]}"

        nombre="${TAREAS[$i]##*$ETIQUETA }"

        printf "%-4s | %-25.25s | %-34.34s | %-15s\n" \
            "$((i+1))" \
            "$nombre" \
            "$(traducir "$mi" "$ho" "$di" "$me" "$ds")" \
            "$mi $ho $di $me $ds"
    done
}

# ==========================================================
# OPCION 2: AGREGAR TAREA
# ==========================================================

agregar_tarea() {
    local op CMD NOMBRE EXPR h m d r me
    local a b c e f

    echo
    echo "================ AGREGAR TAREA ================"
    echo "1) Reporte del sistema (reporte.sh)"
    echo "2) Analisis de servidores (analisis.sh)"
    echo "3) Otro comando personalizado"

    read -rp "Que quieres ejecutar? (1-3): " op

    case "$op" in
        1)
            CMD="/bin/bash $DIR_SCRIPTS/reporte.sh >> $DIR_LOGS/cron_reporte.log 2>&1"
            NOMBRE="Reporte del sistema"
            ;;

        2)
            CMD="/bin/bash $DIR_SCRIPTS/analisis.sh --auto >> $DIR_LOGS/cron_analisis.log 2>&1"
            NOMBRE="Analisis de servidores"
            ;;

        3)
            read -rp "Escribe el comando: " CMD

            if [[ -z "$CMD" || "$CMD" == *%* || "$CMD" == *"#"* ]]; then
                error "Comando vacio o con simbolos no permitidos (% o #)."
                return
            fi

            NOMBRE="Comando personalizado"
            ;;

        *)
            error "Opcion no valida."
            return
            ;;
    esac

    read -rp "Nombre de la tarea (ENTER = '$NOMBRE'): " r
    [[ -n "$r" ]] && NOMBRE="${r//#/}"

    echo
    echo "FRECUENCIA DE EJECUCION"
    echo "1) Cada cierta cantidad de minutos"
    echo "2) Cada hora"
    echo "3) Todos los dias a una hora"
    echo "4) Un dia de la semana"
    echo "5) Un dia del mes"
    echo "6) Una fecha especifica del ano"

    read -rp "Opcion (1-6): " op

    case "$op" in
        1)
            pedir_numero "Cada cuantos minutos" 1 59
            EXPR="*/$NUM * * * *"
            ;;

        2)
            pedir_numero "En que minuto de cada hora" 0 59
            EXPR="$NUM * * * *"
            ;;

        3)
            pedir_numero "Hora (formato 24h)" 0 23
            h=$NUM

            pedir_numero "Minuto" 0 59
            m=$NUM

            EXPR="$m $h * * *"
            ;;

        4)
            echo "1) Lunes  2) Martes  3) Miercoles"
            echo "4) Jueves 5) Viernes 6) Sabado 7) Domingo"

            pedir_numero "Dia de la semana" 1 7
            d=$NUM

            [[ "$d" -eq 7 ]] && d=0

            pedir_numero "Hora" 0 23
            h=$NUM

            pedir_numero "Minuto" 0 59
            m=$NUM

            EXPR="$m $h * * $d"
            ;;

        5)
            pedir_numero "Dia del mes" 1 31
            d=$NUM

            pedir_numero "Hora" 0 23
            h=$NUM

            pedir_numero "Minuto" 0 59
            m=$NUM

            (( d > 28 )) && aviso "Algunos meses no tienen ese dia."

            EXPR="$m $h $d * *"
            ;;

        6)
            echo "1) Enero 2) Febrero 3) Marzo 4) Abril"
            echo "5) Mayo 6) Junio 7) Julio 8) Agosto"
            echo "9) Septiembre 10) Octubre 11) Noviembre 12) Diciembre"

            pedir_numero "Mes" 1 12
            me=$NUM

            pedir_numero "Dia" 1 "${DIAS_MES[$me]}"
            d=$NUM

            pedir_numero "Hora" 0 23
            h=$NUM

            pedir_numero "Minuto" 0 59
            m=$NUM

            EXPR="$m $h $d $me *"
            ;;

        *)
            error "Opcion no valida."
            return
            ;;
    esac

    read -r a b c e f <<< "$EXPR"

    echo
    echo "========== RESUMEN DE LA TAREA =========="
    echo "Nombre: $NOMBRE"
    echo "Se ejecuta: $(traducir "$a" "$b" "$c" "$e" "$f")"
    echo "Codigo cron: $EXPR"
    echo "Comando: $CMD"

    read -rp "Guardar la tarea? (s/n): " r

    [[ "$r" =~ ^[sS]$ ]] || {
        aviso "Tarea cancelada."
        return
    }

    if { crontab -l 2>/dev/null; echo "$EXPR $CMD $ETIQUETA $NOMBRE"; } | crontab -; then
        ok "Tarea programada correctamente."
    else
        error "No se pudo guardar la tarea."
    fi
}

# ==========================================================
# OPCION 3: ELIMINAR TAREA
# ==========================================================

eliminar_tarea() {
    ver_tareas || return

    local n r LINEA

    read -rp "Numero de la tarea a eliminar (0 = cancelar): " n

    [[ "$n" =~ ^[0-9]+$ ]] || {
        error "Escribe un numero valido."
        return
    }

    (( n == 0 )) && {
        aviso "Operacion cancelada."
        return
    }

    (( n <= ${#TAREAS[@]} )) || {
        error "Ese numero no existe."
        return
    }

    LINEA="${TAREAS[$((n-1))]}"

    read -rp "Seguro que deseas eliminar '${LINEA##*$ETIQUETA }'? (s/n): " r

    [[ "$r" =~ ^[sS]$ ]] || {
        aviso "Eliminacion cancelada."
        return
    }

    if crontab -l 2>/dev/null |
        LINEA="$LINEA" awk 'BEGIN {t=ENVIRON["LINEA"]}
        $0==t && !x {x=1; next} {print}' | crontab -; then
        ok "Tarea eliminada."
    else
        error "No se pudo eliminar la tarea."
    fi
}

# ==========================================================
# OPCION 4: VER REGISTROS
# ==========================================================

ver_logs() {
    echo
    echo "REGISTROS DE EJECUCION EN $DIR_LOGS"

    local f encontrado=0

    for f in "$DIR_LOGS"/*.log; do
        [[ -f "$f" ]] || continue

        encontrado=1

        echo
        echo "----- $(basename "$f") -----"
        tail -n 5 "$f"
    done

    if (( encontrado == 0 )); then
        aviso "Aun no hay registros. Las tareas todavia no se ejecutaron."
    fi
}

# ==========================================================
# MENU PRINCIPAL
# ==========================================================

while true; do
    clear 2>/dev/null

    echo "================================================="
    echo "       PROGRAMADOR DE TAREAS AUTOMATICAS"
    echo "================================================="
    echo "Hora del servidor: $(date '+%A %d/%m/%Y %H:%M')"
    echo
    echo "1) Ver tareas programadas"
    echo "2) Agregar una tarea"
    echo "3) Eliminar una tarea"
    echo "4) Ver registros de ejecucion"
    echo "5) Salir"
    echo

    read -rp "Elige una opcion (1-5): " OP

    case "$OP" in
        1) ver_tareas ;;
        2) agregar_tarea ;;
        3) eliminar_tarea ;;
        4) ver_logs ;;
        5) echo "Hasta luego."; exit 0 ;;
        *) error "Opcion no valida." ;;
    esac

    echo
    read -rp "Presiona ENTER para continuar..." _
done

