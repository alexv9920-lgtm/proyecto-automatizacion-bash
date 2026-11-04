#!/bin/bash

BASE="$HOME/proyecto_bash"
ARCHIVO="$BASE/analisis/servidores.csv"
FECHA=$(date '+%Y%m%d_%H%M%S')
REPORTE="$BASE/reportes/reporte_awk_$FECHA.txt"

if [[ ! -f "$ARCHIVO" ]]; then
    echo "Error: no existe el inventario $ARCHIVO"
    exit 1
fi

{
    echo "=============================================="
    echo "       REPORTE DE SERVIDORES CON AWK"
    echo "=============================================="
    echo "Fecha: $(date)"
    echo
    printf "%-15s %-12s %-12s %-12s %-12s\n" \
        "SERVIDOR" "DISCO(%)" "CPU(%)" "MEMORIA(%)" "ESTADO"

    awk -F';' '
    !/^#/ && NF >= 6 {
        estado = ($4 > 70 || $5 > 70 || $6 > 70) ? "ALERTA" : "NORMAL"

        printf "%-15s %-12s %-12s %-12s %-12s\n", \
            $1, $4, $5, $6, estado

        total++
        if (estado == "ALERTA") alertas++
    }

    END {
        print ""
        print "Total de servidores: " total
        print "Servidores en alerta: " (alertas + 0)
        print "Servidores normales: " (total - alertas)
    }
    ' "$ARCHIVO"

} | tee "$REPORTE"

echo
echo "Reporte generado: $REPORTE"
