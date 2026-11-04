#!/bin/bash

# ==========================================
# SCRIPT: LIMPIEZA DE ARCHIVOS TEMPORALES
# ==========================================

BASE="$HOME/proyecto_bash"
DIRECTORIO="$BASE/temporales"
LOG="$BASE/logs/limpieza.log"

mkdir -p "$DIRECTORIO" "$BASE/logs"

echo "======================================"
echo "       LIMPIEZA DE TEMPORALES"
echo "======================================"
echo "Directorio: $DIRECTORIO"
echo

echo "Archivos encontrados:"
find "$DIRECTORIO" -maxdepth 1 -type f -printf '%f\n'

echo
read -r -p "Eliminar archivos con más de cuántos días?: " DIAS

if ! [[ "$DIAS" =~ ^[0-9]+$ ]]; then
    echo "Error: debes ingresar un número entero."
    exit 1
fi

echo
echo "Archivos que cumplen el criterio:"
find "$DIRECTORIO" -maxdepth 1 -type f -mtime +"$DIAS" -print

read -r -p "¿Confirmas la eliminación? (s/n): " CONFIRMACION

if [[ "$CONFIRMACION" == "s" || "$CONFIRMACION" == "S" ]]; then

    CANTIDAD=$(find "$DIRECTORIO" -maxdepth 1 -type f -mtime +"$DIAS" | wc -l)

    find "$DIRECTORIO" -maxdepth 1 -type f -mtime +"$DIAS" -delete

    echo "$(date '+%F %T') - Limpieza ejecutada. Archivos eliminados: $CANTIDAD" >> "$LOG"

    echo "Limpieza completada."
    echo "Archivos eliminados: $CANTIDAD"

else
    echo "Operación cancelada."
    echo "$(date '+%F %T') - Limpieza cancelada por el usuario." >> "$LOG"
fi
