#!/bin/bash

BASE="$HOME/proyecto_bash"
mkdir -p "$BASE/reportes" "$BASE/analisis"

REPORTE="$BASE/reportes/ultimo_reporte.txt"

{
    echo "=================================="
    echo "       REPORTE DEL PROYECTO"
    echo "=================================="
    echo "Fecha: $(date)"
    echo "Usuario: $(whoami)"
    echo "Servidor: $(hostname)"
    echo "Sistema operativo:"
    uname -a
    echo ""
    echo "Uso de disco:"
    df -h /
    echo ""
    echo "Uso de memoria:"
    free -h
    echo ""
    echo "Scripts disponibles:"
    ls -lh "$BASE/scripts/"
    echo "=================================="
} > "$REPORTE"

echo "Reporte generado correctamente: $REPORTE"
