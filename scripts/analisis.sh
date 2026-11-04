
#!/bin/bash
# ==========================================================
# SCRIPT 3: ANALISIS DE SERVIDORES
# Monitoreo de disco, CPU y memoria
# ==========================================================

BASE="$HOME/proyecto_bash"
DIR_REP="$BASE/reportes"
DIR_AN="$BASE/analisis"
INVENTARIO="$DIR_AN/servidores.csv"
ALERTADOS="$DIR_AN/servidores_alertados.txt"
HISTORIAL="$DIR_AN/historial_revisiones.txt"
UMBRAL=70

mkdir -p "$DIR_REP" "$DIR_AN"

VERDE=$'\033[0;32m'
AMARILLO=$'\033[1;33m'
ROJO=$'\033[0;31m'
AZUL=$'\033[0;36m'
NC=$'\033[0m'

colorear() {
    sed -e "s/CRITICO/${ROJO}CRITICO${NC}/g" \
        -e "s/NORMAL/${VERDE}NORMAL${NC}/g" \
        -e "s/ALERTA/${AMARILLO}ALERTA${NC}/g" \
        -e "s/REVISADO/${VERDE}REVISADO${NC}/g"
}

# Crear inventario de ejemplo si no existe
if [[ ! -f "$INVENTARIO" ]]; then
    cat > "$INVENTARIO" <<'EOF'
# nombre;ip;ruta;disco%;cpu%;memoria%
SRV-WEB01;192.168.10.11;/var/www;85;45;60
SRV-BD01;192.168.10.12;/var/lib/mysql;72;81;77
SRV-APP01;192.168.10.13;/opt/app;40;30;55
SRV-FILES;192.168.10.14;/srv/files;93;20;35
SRV-MAIL;192.168.10.15;/var/mail;35;25;40
EOF
fi

# Medir CPU real
uso_cpu() {
    local u1 n1 s1 i1 w1 q1 sq1 st1
    local u2 n2 s2 i2 w2 q2 sq2 st2

    read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
    sleep 1
    read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat

    local total=$((u2+n2+s2+i2+w2+q2+sq2+st2-u1-n1-s1-i1-w1-q1-sq1-st1))
    local libre=$((i2+w2-i1-w1))

    (( total <= 0 )) && { echo 0; return; }

    echo $((100*(total-libre)/total))
}

# Medir memoria y disco
uso_memoria() {
    free | awk '/^Mem:/ {printf "%d", $3*100/$2}'
}

uso_disco() {
    df -P / | awk 'NR==2 {gsub("%","",$5); print $5}'
}

# Obtener datos del servidor local
datos_local() {
    echo "$(hostname);$(hostname -I 2>/dev/null | awk '{print $1}');/;$(uso_disco);$(uso_cpu);$(uso_memoria)"
}

# Unir servidor local e inventario
todos_los_servidores() {
    datos_local
    grep -v '^[[:space:]]*#' "$INVENTARIO" |
        grep -v '^[[:space:]]*$'
}

# Evaluar estado de cada servidor
evaluar() {
    local d="$1" c="$2" m="$3"

    MOTIVO=""

    (( d > UMBRAL )) && MOTIVO+="DISCO "
    (( c > UMBRAL )) && MOTIVO+="CPU "
    (( m > UMBRAL )) && MOTIVO+="MEM "

    if [[ -n "$MOTIVO" ]]; then
        EST="CRITICO"
        MOTIVO="${MOTIVO% }"
    else
        EST="NORMAL"
        MOTIVO="-"
    fi
}

# Funciones de tabla
linea() {
    echo "+------------+-----------------+-----------------+-------+------+-------+----------+----------------+"
}

cabeza() {
    linea
    printf "| %-10s | %-15s | %-15s | %-5s | %-4s | %-5s | %-8s | %-14s |\n" \
        "SERVIDOR" "IP" "RUTA" "DISCO" "CPU" "MEM" "ESTADO" "MOTIVO"
    linea
}

fila() {
    printf "| %-10s | %-15s | %-15s | %4s%% | %3s%% | %4s%% | %-8s | %-14s |\n" "$@"
}

# ==========================================================
# OPCION 1: ANALISIS COMPLETO
# ==========================================================

analizar() {
    local SELLO FECHA TMP n ip ruta d c m est l
    local total=0 criticos=0
    local -a DATOS

    SELLO=$(date '+%Y%m%d_%H%M%S')
    FECHA=$(date '+%d/%m/%Y %H:%M:%S')
    TMP=$(mktemp)

    echo "Analizando servidores..."
    mapfile -t DATOS < <(todos_los_servidores)

    : > "$ALERTADOS.tmp"

    {
        echo "=============================================================="
        echo "ANALISIS DE SERVIDORES | Fecha: $FECHA | Usuario: $(whoami)"
        echo "Umbral de alerta: ${UMBRAL}%"
        echo "=============================================================="
        echo
        echo "[1] FILTRO: SERVIDORES CON USO MAYOR AL ${UMBRAL}%"

        cabeza

        for l in "${DATOS[@]}"; do
            IFS=';' read -r n ip ruta d c m <<< "$l"
            evaluar "$d" "$c" "$m"
            est="$EST"

            if [[ "$est" == "CRITICO" ]]; then
                fila "$n" "$ip" "$ruta" "$d" "$c" "$m" "$est" "$MOTIVO"
                echo "$n;$ip;$ruta;$d;$c;$m;$FECHA" >> "$ALERTADOS.tmp"
            fi
        done

        linea
        echo
        echo "[2] LISTA COMPLETA DE SERVIDORES"
        cabeza

        for l in "${DATOS[@]}"; do
            IFS=';' read -r n ip ruta d c m <<< "$l"
            evaluar "$d" "$c" "$m"
            fila "$n" "$ip" "$ruta" "$d" "$c" "$m" "$EST" "$MOTIVO"
        done

        linea
    } > "$TMP"

    total=${#DATOS[@]}
    criticos=$(wc -l < "$ALERTADOS.tmp")

    mv "$ALERTADOS.tmp" "$ALERTADOS"

    local ESTADO_GENERAL

    if (( criticos > 0 )); then
        ESTADO_GENERAL="CRITICO"
    else
        ESTADO_GENERAL="NORMAL"
    fi

    REPORTE="$DIR_REP/analisis_${ESTADO_GENERAL}_${SELLO}.txt"

    {
        cat "$TMP"
        echo
        echo "RESUMEN: $total servidores analizados | $criticos CRITICO(S) | $((total-criticos)) NORMAL(ES)"
        echo "ESTADO GENERAL: $ESTADO_GENERAL"
        echo "Servidores alertados guardados en: $ALERTADOS"
        echo ">>> ANALISIS FINALIZADO <<<"
    } > "$REPORTE"

    rm -f "$TMP"

    colorear < "$REPORTE"
    echo
    echo "Reporte guardado en: $REPORTE"
}

# ==========================================================
# OPCION 2: RE-REVISAR SERVIDORES ALERTADOS
# ==========================================================

revisar() {
    if [[ ! -s "$ALERTADOS" ]]; then
        echo "No hay servidores alertados. Ejecuta primero la opcion 1."
        return
    fi

    local SELLO FECHA LOCAL_HOST LOCAL_DATOS
    local n ip ruta d c m f actual res
    local sigue=0 rev=0

    SELLO=$(date '+%Y%m%d_%H%M%S')
    FECHA=$(date '+%d/%m/%Y %H:%M:%S')
    LOCAL_HOST=$(hostname)
    LOCAL_DATOS=$(datos_local)
    REPORTE="$DIR_REP/revision_${SELLO}.txt"

    : > "$ALERTADOS.tmp"

    {
        echo "=============================================================="
        echo "RE-REVISION DE SERVIDORES ALERTADOS | Fecha: $FECHA"
        echo "=============================================================="

        cabeza

        while IFS=';' read -r n ip ruta d c m f; do
            [[ -z "$n" ]] && continue

            if [[ "$n" == "$LOCAL_HOST" ]]; then
                actual="$LOCAL_DATOS"
            else
                actual=$(grep -F "$n;" "$INVENTARIO" | head -1)
            fi

            [[ -z "$actual" ]] && continue

            IFS=';' read -r n ip ruta d c m <<< "$actual"
            evaluar "$d" "$c" "$m"

            if [[ "$EST" == "CRITICO" ]]; then
                res="ALERTA"
                ((sigue++))
                echo "$n;$ip;$ruta;$d;$c;$m;$FECHA" >> "$ALERTADOS.tmp"
            else
                res="REVISADO"
                ((rev++))
            fi

            fila "$n" "$ip" "$ruta" "$d" "$c" "$m" "$res" "$MOTIVO"
            echo "$FECHA | $n | $ip | $res" >> "$HISTORIAL"

        done < "$ALERTADOS"

        linea
        echo "RESULTADO: $rev REVISADO(S) | $sigue siguen en ALERTA"
        echo ">>> REVISION FINALIZADA <<<"

    } > "$REPORTE"

    mv "$ALERTADOS.tmp" "$ALERTADOS"

    colorear < "$REPORTE"

    echo
    echo "Reporte de revision guardado en: $REPORTE"
    echo "Historial de revisiones: $HISTORIAL"
}

# ==========================================================
# OPCION 3: PARTICIONES DEL SERVIDOR LOCAL
# ==========================================================

discos_local() {
    echo
    echo "PARTICIONES DE $(hostname)"
    df -hP -x tmpfs -x devtmpfs -x squashfs -x overlay
}

# ==========================================================
# OPCION 4: VER INVENTARIO, ALERTADOS Y REPORTES
# ==========================================================

ver_archivos() {
    echo
    echo "INVENTARIO:"
    cat "$INVENTARIO"

    echo
    echo "SERVIDORES ALERTADOS:"
    if [[ -s "$ALERTADOS" ]]; then
        cat "$ALERTADOS"
    else
        echo "(ninguno)"
    fi

    echo
    echo "REPORTES GUARDADOS:"
    ls -1 "$DIR_REP" | grep -E '^(analisis|revision)_' || true
}

# MODO AUTOMATICO PARA CRON
if [[ "$1" == "--auto" ]]; then
    analizar
    exit 0
fi

# ==========================================================
# MENU PRINCIPAL
# ==========================================================

while true; do
    clear 2>/dev/null

    echo "================================================="
    echo "          ANALISIS DE SERVIDORES"
    echo "================================================="
    echo "Umbral de alerta: ${UMBRAL}%"
    echo
    echo "1) Ejecutar analisis"
    echo "2) Re-revisar servidores alertados"
    echo "3) Ver discos del servidor local"
    echo "4) Ver inventario, alertados y reportes"
    echo "5) Salir"
    echo

    read -rp "Elige una opcion (1-5): " OP

    case "$OP" in
        1) analizar ;;
        2) revisar ;;
        3) discos_local ;;
        4) ver_archivos ;;
        5) echo "Hasta luego."; exit 0 ;;
        *) echo "Opcion no valida." ;;
    esac

    echo
    read -rp "Presiona ENTER para continuar..." _
done

