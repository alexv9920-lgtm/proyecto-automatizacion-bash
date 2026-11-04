
#!/bin/bash
# SCRIPT 2: GESTOR DE ARCHIVOS

BASE="$HOME/proyecto_bash/gestor_de_archivos"
LOG="$HOME/proyecto_bash/reportes/gestor_log.txt"

mkdir -p "$BASE" "$(dirname "$LOG")"
BASE_REAL=$(realpath "$BASE")

VERDE=$'\033[0;32m'
AMARILLO=$'\033[1;33m'
ROJO=$'\033[0;31m'
AZUL=$'\033[0;36m'
NC=$'\033[0m'

ok() { echo "${VERDE}[OK]${NC} $1"; }
error() { echo "${ROJO}[X]${NC} $1"; }
aviso() { echo "${AMARILLO}[!]${NC} $1"; }

registrar() {
    echo "$(date '+%d/%m/%Y %H:%M:%S') | $(whoami) | $1" >> "$LOG"
}

pausa() {
    echo
    read -rp "Presiona ENTER para continuar..." _
}

# Validar nombres y bloquear rutas externas
nombre_valido() {
    local n="$1"

    if [[ -z "$n" ]]; then
        error "No escribiste ningun nombre."
        return 1
    fi

    if [[ "$n" == */* || "$n" == *..* ]]; then
        error "BLOQUEADO: no puedes salir de la carpeta."
        registrar "INTENTO BLOQUEADO: $n"
        return 1
    fi

    if [[ "$n" == -* || "$n" == .* ]]; then
        error "El nombre no puede empezar con - ni con ."
        return 1
    fi

    if [[ ! "$n" =~ ^[A-Za-z0-9._-]+$ ]]; then
        error "Nombre no valido. No uses espacios ni simbolos especiales."
        return 1
    fi

    return 0
}

dentro_de_carpeta() {
    local ruta
    ruta=$(realpath -m "$BASE/$1")
    [[ "$(dirname "$ruta")" == "$BASE_REAL" ]]
}

# Convertir permisos octales a texto
octal_a_texto() {
    local res="" d

    for d in $(echo "$1" | grep -o .); do
        (( d & 4 )) && res+="r" || res+="-"
        (( d & 2 )) && res+="w" || res+="-"
        (( d & 1 )) && res+="x" || res+="-"
    done

    echo "$res"
}

explicar_permisos() {
    local p="$1"
    local quien=("Dueno" "Grupo" "Otros")
    local i d txt

    for i in 0 1 2; do
        d=${p:$i:1}
        txt=""

        (( d & 4 )) && txt+="leer, "
        (( d & 2 )) && txt+="escribir, "
        (( d & 1 )) && txt+="ejecutar, "

        [[ -z "$txt" ]] && txt="sin acceso, "

        echo "${quien[$i]}: ${txt%, }"
    done
}

ARCH=""

# Elegir archivo por numero o nombre
elegir_archivo() {
    ARCH=""
    local archivos=() f i sel

    for f in "$BASE"/*; do
        [[ -f "$f" && ! -L "$f" ]] &&
            archivos+=("$(basename "$f")")
    done

    if [[ ${#archivos[@]} -eq 0 ]]; then
        aviso "La carpeta esta vacia. Primero crea un archivo."
        return 1
    fi

    echo
    echo "ARCHIVOS DISPONIBLES"

    for i in "${!archivos[@]}"; do
        f="$BASE/${archivos[$i]}"
        printf "%s) %-25s Permisos: %-10s Dueno: %-12s Tamano: %s\n" \
            "$((i+1))" "${archivos[$i]}" \
            "$(stat -c '%A' "$f" | cut -c2-)" \
            "$(stat -c '%U' "$f")" \
            "$(du -h "$f" | cut -f1)"
    done

    read -rp "Escribe el numero o nombre del archivo: " sel

    if [[ "$sel" =~ ^[0-9]+$ ]] &&
       (( sel >= 1 && sel <= ${#archivos[@]} )); then
        ARCH="${archivos[$((sel-1))]}"
    else
        nombre_valido "$sel" || return 1
        dentro_de_carpeta "$sel" || return 1
        [[ -f "$BASE/$sel" && ! -L "$BASE/$sel" ]] || {
            error "El archivo no existe."
            return 1
        }
        ARCH="$sel"
    fi
}

# OPCION 1: CREAR
crear_archivo() {
    local n c

    read -rp "Nombre del nuevo archivo: " n
    nombre_valido "$n" || return

    if [[ -e "$BASE/$n" ]]; then
        aviso "El archivo ya existe. No se sobrescribira."
        return
    fi

    read -rp "Contenido (ENTER para archivo vacio): " c

    if [[ -n "$c" ]]; then
        printf '%s\n' "$c" > "$BASE/$n"
    else
        touch "$BASE/$n"
    fi

    ok "Archivo creado: $n"
    registrar "CREAR $n"
}

# OPCION 2: COPIAR
copiar_archivo() {
    local d r

    elegir_archivo || return

    read -rp "Nombre de la copia (ENTER = copia_$ARCH): " d
    [[ -z "$d" ]] && d="copia_$ARCH"

    nombre_valido "$d" || return

    if [[ -e "$BASE/$d" ]]; then
        read -rp "Ya existe. Reemplazar? (s/n): " r
        [[ "$r" =~ ^[sS]$ ]] || return
    fi

    if cp -p -- "$BASE/$ARCH" "$BASE/$d"; then
        ok "Copia realizada correctamente."
        registrar "COPIAR $ARCH -> $d"
    else
        error "No se pudo copiar."
    fi
}

# Aplicar permisos
aplicar_permisos() {
    local p="$1" r

    echo "Permisos seleccionados: $p"
    echo "Equivalencia: $(octal_a_texto "$p")"
    explicar_permisos "$p"

    read -rp "Aplicar estos permisos? (s/n): " r
    [[ "$r" =~ ^[sS]$ ]] || return

    if chmod "$p" "$BASE/$ARCH"; then
        ok "Permisos aplicados correctamente."
        registrar "PERMISOS $ARCH -> $p"
    else
        error "No se pudieron aplicar los permisos."
    fi
}

elegir_nivel() {
    local quien="$1" op

    echo "Permisos para $quien:"
    echo "1) Nada"
    echo "2) Solo leer"
    echo "3) Leer y escribir"
    echo "4) Leer y ejecutar"
    echo "5) Todo"

    read -rp "Opcion: " op

    case "$op" in
        1) NIVEL=0 ;;
        2) NIVEL=4 ;;
        3) NIVEL=6 ;;
        4) NIVEL=5 ;;
        5) NIVEL=7 ;;
        *) error "Opcion no valida."; return 1 ;;
    esac
}

permisos_guiados() {
    local op u g o

    echo "1) PRIVADO       (600)"
    echo "2) COMPARTIDO    (644)"
    echo "3) EJECUTABLE    (755)"
    echo "4) SOLO LECTURA  (444)"
    echo "5) PERSONALIZADO"

    read -rp "Opcion: " op

    case "$op" in
        1) aplicar_permisos 600 ;;
        2) aplicar_permisos 644 ;;
        3) aplicar_permisos 755 ;;
        4) aplicar_permisos 444 ;;
        5)
            elegir_nivel "DUENO" || return
            u=$NIVEL
            elegir_nivel "GRUPO" || return
            g=$NIVEL
            elegir_nivel "OTROS" || return
            o=$NIVEL
            aplicar_permisos "$u$g$o"
            ;;
        *) error "Opcion no valida." ;;
    esac
}

cambiar_propietario() {
    local usuarios=() i sel nuevo

    mapfile -t usuarios < <(
        awk -F: '$3==0 || ($3>=1000 && $3<65534) {print $1}' /etc/passwd
    )

    echo "Usuarios disponibles:"
    for i in "${!usuarios[@]}"; do
        echo "$((i+1))) ${usuarios[$i]}"
    done

    read -rp "Numero del nuevo dueno: " sel

    if [[ ! "$sel" =~ ^[0-9]+$ ]] ||
       (( sel < 1 || sel > ${#usuarios[@]} )); then
        error "Opcion no valida."
        return
    fi

    nuevo="${usuarios[$((sel-1))]}"

    if sudo chown "$nuevo" "$BASE/$ARCH"; then
        ok "Propietario cambiado."
        registrar "DUENO $ARCH -> $nuevo"
    else
        error "No se pudo cambiar el propietario."
    fi
}

# OPCION 3: PERMISOS / DUENO
cambiar_permisos() {
    local op p

    elegir_archivo || return

    p=$(stat -c '%a' "$BASE/$ARCH")

    echo "Permisos actuales: $p"
    echo "Equivalencia: $(octal_a_texto "$p")"
    explicar_permisos "$p"

    echo "1) Cambiar permisos"
    echo "2) Cambiar dueno"

    read -rp "Opcion: " op

    case "$op" in
        1) permisos_guiados ;;
        2) cambiar_propietario ;;
        *) error "Opcion no valida." ;;
    esac
}

# OPCION 4: ELIMINAR
eliminar_archivo() {
    local r

    aviso "Solo se eliminan archivos dentro de $BASE"

    elegir_archivo || return
    dentro_de_carpeta "$ARCH" || {
        error "BLOQUEADO: fuera de la carpeta permitida."
        registrar "INTENTO BLOQUEADO ELIMINACION: $ARCH"
        return
    }

    read -rp "Eliminar definitivamente $ARCH? (s/n): " r
    [[ "$r" =~ ^[sS]$ ]] || {
        aviso "Eliminacion cancelada."
        return
    }

    if rm -f -- "$BASE/$ARCH" && [[ ! -e "$BASE/$ARCH" ]]; then
        ok "Archivo eliminado."
        registrar "ELIMINAR $ARCH"
    else
        error "No se pudo eliminar."
    fi
}

# MENU PRINCIPAL
trap 'echo; exit 0' INT

while true; do
    clear 2>/dev/null

    echo "=========================================="
    echo "       GESTOR DE ARCHIVOS"
    echo "=========================================="
    echo "Usuario: $(whoami)"
    echo "Carpeta: $BASE"
    echo "------------------------------------------"
    echo "1) Crear archivo"
    echo "2) Copiar archivo"
    echo "3) Cambiar permisos / dueno"
    echo "4) Eliminar archivo"
    echo "5) Salir"
    echo "------------------------------------------"

    read -rp "Elige una opcion (1-5): " OPCION

    case "$OPCION" in
        1) crear_archivo; pausa ;;
        2) copiar_archivo; pausa ;;
        3) cambiar_permisos; pausa ;;
        4) eliminar_archivo; pausa ;;
        5) ok "Hasta luego."; exit 0 ;;
        *) error "Opcion no valida."; sleep 2 ;;
    esac
done

