#!/bin/bash

BASE="$HOME/proyecto_bash"
ARCHIVO="$BASE/reportes/observaciones.txt"

echo "======================================"
echo "       REEMPLAZO DE TEXTO CON SED"
echo "======================================"

if [[ ! -f "$ARCHIVO" ]]; then
    echo "Error: el archivo no existe."
    exit 1
fi

read -r -p "Palabra que deseas reemplazar: " BUSCAR
read -r -p "Nueva palabra: " REEMPLAZAR

if [[ -z "$BUSCAR" || -z "$REEMPLAZAR" ]]; then
    echo "Error: los campos no pueden estar vacíos."
    exit 1
fi

# Crear respaldo antes de modificar
cp -- "$ARCHIVO" "$ARCHIVO.bak"

# Reemplazar todas las coincidencias de la palabra
sed -i "s|$BUSCAR|$REEMPLAZAR|g" "$ARCHIVO"

echo
echo "Reemplazo realizado."
echo "Contenido actualizado:"
cat "$ARCHIVO"

echo
echo "Copia de seguridad: $ARCHIVO.bak"
