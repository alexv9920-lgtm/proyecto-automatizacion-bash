#!/bin/bash

BASE="$HOME/proyecto_bash"
DIRECTORIO="$BASE/gestor_de_archivos"

echo "======================================"
echo "     ELIMINAR ARCHIVOS POR FECHA"
echo "======================================"

if [[ ! -d "$DIRECTORIO" ]]; then
    echo "No existe el directorio de trabajo."
    exit 1
fi

read -r -p "Ingresa la fecha (AAAA-MM-DD): " FECHA

if ! [[ "$FECHA" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
   ! date -d "$FECHA" >/dev/null 2>&1 ||
   [[ "$(date -d "$FECHA" +%F)" != "$FECHA" ]]; then
    echo "Fecha inválida. Usa el formato AAAA-MM-DD."
    exit 1
fi

echo
echo "Archivos modificados antes de $FECHA:"
find "$DIRECTORIO" -maxdepth 1 -type f ! -newermt "$FECHA" -printf '%f\n'

read -r -p "¿Deseas eliminar estos archivos? (s/n): " CONFIRMAR

if [[ "$CONFIRMAR" == "s" || "$CONFIRMAR" == "S" ]]; then
    find "$DIRECTORIO" -maxdepth 1 -type f ! -newermt "$FECHA" -delete
    echo "Eliminación completada."
else
    echo "Operación cancelada."
fi
