#!/data/data/com.termux/files/usr/bin/bash
#
# OpenCode — Termux
# Script de instalacion para Termux
# v2.0.0
#
# Script creado por Sebastian Laguna
# https://github.com/sebastianl1/opencode-termux
#
# Descripcion:
#   Instala OpenCode de forma nativa en Termux: descarga el binario
#   oficial (build glibc) y lo ejecuta con un launcher nativo Android
#   a traves de la capa glibc de Termux.
#   Multi-fuente: vendor oficial, espejo propio y termuxvoid.
#   Sin proot, sin VMs, sin Cloud Shell.
#
# Uso:
#   bash install.sh              Instalacion completa
#   bash install.sh --help       Muestra esta ayuda
#   bash install.sh --version    Muestra la version
#   bash install.sh --uninstall  Desinstala opencode
#

set -eEuo pipefail

# ── Configuracion ────────────────────────────────────────────────────────────

SCRIPT_VERSION="2.0.0"
SCRIPT_AUTHOR="Sebastian Laguna"
SCRIPT_REPO="https://github.com/sebastianl1/opencode-termux"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OPCODE_BIN_DIR="$PREFIX/bin"
OPCODE_SHARE_DIR="$PREFIX/share/opencode"
OPCODE_REAL="$OPCODE_SHARE_DIR/opencode.real"
OPCODE_CONFIG_DIR="$HOME/.config/opencode"
OPCODE_CONFIG_FILE="$OPCODE_CONFIG_DIR/opencode.json"
GLIBC_LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
GLIBC_LIB="$PREFIX/glibc/lib"
GLIBC_RUNTIME="$OPCODE_SHARE_DIR/glibc-runtime"
BACKUP_DIR="$HOME/backups/opencode"
TMP_DIR="$PREFIX/tmp/opencode-install"
LOG_FILE="$TMP_DIR/install.log"
INSTALL_FAILED=false
INSTALL_METHOD=""
INSTALL_LAUNCHER=""

# Fuentes del binario (por prioridad):
#   A. Vendor oficial  -> GitHub de anomalyco/opencode (siempre ultima)
#   B. Espejo propio   -> GitHub Releases de este repositorio
#   C. npm oficial     -> paquete de plataforma 'opencode-linux-arm64'
#   D. termuxvoid      -> paquete Termux 'opencode' (ultimo recurso)
VENDOR_DL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-arm64.tar.gz"
MIRROR_DL="https://github.com/sebastianl1/opencode-termux/releases/latest/download/opencode-linux-arm64.tar.gz"

# ── Colores (profesionales, sin llamativos) ─────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
WHITE="\033[97m"
RESET="\033[0m"

# ── Dimensiones ─────────────────────────────────────────────────────────────

COLS=66

# ── Funciones de dibujo ─────────────────────────────────────────────────────

make_line() {
    local char="${1:-─}"
    local line=""
    printf -v line "%*s" "$COLS" ""
    echo "${line// /${char}}"
}

box_line() {
    echo -e "  ${BLUE}${BOLD}$1${RESET}"
}

box_text() {
    local content="$1"
    local color="${2:-}"
    local padding=$(( COLS - ${#content} - 2 ))
    printf "  ${BLUE}${BOLD}│${RESET} ${color}%s${RESET}%*s${BLUE}${BOLD}│${RESET}\n" "$content" "$padding" ""
}

section_header() {
    local title="$1"
    echo ""
    echo -e "  ${BLUE}${BOLD}◆ ${title}${RESET}"
    echo -e "  ${BLUE}${DIM}$(make_line)${RESET}"
    echo ""
}

check_item() {
    local label="$1"
    local status="$2"
    local detail="${3:-}"

    if [ "$status" = "ok" ]; then
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET}" "$label"
    elif [ "$status" = "skip" ]; then
        printf "  ${DIM}−${RESET} ${DIM}%-34s${RESET}" "$label"
    else
        printf "  ${YELLOW}⬡${RESET} ${BOLD}%-34s${RESET}" "$label"
    fi

    if [ -n "$detail" ]; then
        echo -e "${DIM}${detail}${RESET}"
    else
        echo ""
    fi
}

# ── Funciones de utilidad ───────────────────────────────────────────────────

cleanup() {
    if [ "$INSTALL_FAILED" = "true" ] && [ -d "$BACKUP_DIR" ]; then
        restore_backup
    fi
    rm -rf "$TMP_DIR" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

print_error() {
    echo -e "\n  ${RED}${BOLD}ERROR${RESET} ${1}"
    exit 1
}

print_info() {
    echo -e "  ${DIM}${1}${RESET}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-S}"
    local yn

    printf "  %s " "$prompt"
    if [ "$default" = "S" ]; then
        printf "${BOLD}[S/n]${RESET}: "
    else
        printf "${BOLD}[s/N]${RESET}: "
    fi

    read -r yn
    yn="${yn:-$default}"

    case "$yn" in
        [Ss]*) return 0 ;;
        *) return 1 ;;
    esac
}

run_hidden() {
    local desc="$1"
    shift

    mkdir -p "$TMP_DIR"

    printf "  ⬡ ${BOLD}%-34s${RESET}" "$desc"

    echo "--- [$desc] $(date) ---" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    local spin='-\|/'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${WHITE}${BOLD}⬡${RESET} ${BOLD}%-34s${RESET} ${DIM}%s${RESET}" "$desc" "${spin:$i:1}"
        i=$(( (i + 1) % 4 ))
        sleep 0.1
    done

    local exit_code=0
    wait "$pid" || exit_code=$?

    printf "\r"

    if [ "$exit_code" -eq 0 ]; then
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET} ${GREEN}hecho${RESET}\n" "$desc"
    else
        printf "  ${RED}✘${RESET} ${BOLD}%-34s${RESET} ${RED}fallo${RESET}\n" "$desc"
        return "$exit_code"
    fi
}

show_log_tail() {
    echo ""
    echo -e "  ${DIM}Ultimas lineas del log:${RESET}"
    tail -15 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}  ${line}${RESET}"
    done
}

explain_termux_failure() {
    local log_content
    log_content=$(cat "$LOG_FILE" 2>/dev/null || true)

    case "$log_content" in
        *"unable to locate package"*|*"E: Unable"*|*"Failed to fetch"*|*"Could not resolve"*|*"curl"*|*"opencode-android-arm64"*|*"Cannot find module"*|*"unexpected e_type"*|*"required file not found"*|*"Binary not found"*|*"failed to install the right opencode"*)
            echo ""
            echo -e "  ${YELLOW}⬡${RESET} ${BOLD}Instalacion nativa de opencode en Termux${RESET}"
            echo -e "  ${DIM}OpenCode se instala con el binario oficial glibc + un${RESET}"
            echo -e "  ${DIM}launcher nativo Android, a traves de la capa glibc de${RESET}"
            echo -e "  ${DIM}Termux. No usa npm ni proot.${RESET}"
            echo ""
            echo -e "  ${BOLD}Si fallaron todas las fuentes, verifica:${RESET}"
            echo -e "  ${DIM}1.${RESET} Conexion a internet (el binario pesa ~90-180MB)"
            echo -e "  ${DIM}2.${RESET} Que la capa glibc quede instalada:"
            echo -e "     ${RESET}pkg install -y glibc-repo && pkg update && pkg install -y glibc"
            echo -e "  ${DIM}3.${RESET} Reintentar en otro momento (descarga de GitHub/npm)"
            echo ""
            ;;
    esac
}

detect_installed_version() {
    if command -v opencode &>/dev/null; then
        opencode --version 2>/dev/null || echo ""
    fi
}

# ── Banner principal ────────────────────────────────────────────────────────

print_banner() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "" ""
    box_text "OpenCode — Termux" "$WHITE${BOLD}"
    box_text "Script de instalacion  v${SCRIPT_VERSION}" "${DIM}"
    box_text "" ""
    box_text "Sebastian Laguna" "${BOLD}"
    box_text "${SCRIPT_REPO}" "${DIM}"
    box_text "" ""
    box_line "├$(make_line)┤"
}

# ── Funciones del instalador ────────────────────────────────────────────────

check_environment() {
    section_header "Preparacion"

    local env_ok=true
    local arch_ok=true

    if [ -n "${TERMUX_VERSION:-}" ]; then
        check_item "Entorno Termux" "ok" ""
    else
        check_item "Entorno Termux" "skip" ""
        env_ok=false
    fi

    if [ "$(uname -m)" = "aarch64" ]; then
        check_item "Arquitectura aarch64" "ok" ""
    else
        check_item "Arquitectura aarch64" "skip" "$(uname -m)"
        arch_ok=false
    fi

    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version 2>/dev/null)
        check_item "Node.js (opcional)" "ok" "$node_ver"
    else
        check_item "Node.js (opcional)" "skip" "no requerido"
    fi

    if command -v npm &>/dev/null; then
        local npm_ver
        npm_ver=$(npm --version 2>/dev/null)
        check_item "npm (opcional)" "ok" "v$npm_ver"
    else
        check_item "npm (opcional)" "skip" "no requerido"
    fi

    echo ""

    if [ "$env_ok" != "true" ] || [ "$arch_ok" != "true" ]; then
        print_error "Este instalador solo funciona en Termux ARM64 (aarch64)."
    fi
}

add_termuxvoid_repo() {
    mkdir -p "$PREFIX/etc/apt/sources.list.d"
    echo "deb [trusted=yes arch=all] https://termuxvoid.github.io/repo termuxvoid main" > "$PREFIX/etc/apt/sources.list.d/termuxvoid.list"
}

check_dependencies() {
    :
}

check_existing() {
    local current_version="$1"

    section_header "Estado actual"

    check_item "OpenCode" "ok" "$current_version"
    check_item "Origen" "ok" "$(command -v opencode)"

    if ! ask_yes_no "¿Reinstalar opencode?" "N"; then
        print_info "Instalacion omitida."
        return 1
    fi
}

backup_existing() {
    section_header "Respaldo"

    if [ -d "$OPCODE_CONFIG_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        cp -r "$OPCODE_CONFIG_DIR" "$BACKUP_DIR/opencode.backup.$ts"
        check_item "Respaldo configuracion" "ok" "$BACKUP_DIR/opencode.backup.$ts"
    else
        check_item "Sin configuracion previa" "ok" ""
    fi
}

restore_backup() {
    local backup_path
    backup_path=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name 'opencode.backup.*' -print -quit 2>/dev/null || true)
    if [ -n "$backup_path" ] && [ -d "$backup_path" ]; then
        cp -r "$backup_path"/* "$OPCODE_CONFIG_DIR/" 2>/dev/null || true
        {
            echo "--- [restore_backup] $(date) ---"
            echo "Configuracion restaurada desde $backup_path"
        } >> "$LOG_FILE"
        echo -e "\n  ${YELLOW}⬡${RESET} Configuracion anterior restaurada desde backup." >&2
    fi
}

ensure_glibc_layer() {
    ensure_glibc_repo

    run_hidden "Instalar capa glibc" pkg install -y glibc ca-certificates ca-certificates-glibc clang curl tar || {
        show_log_tail
        print_error "No se pudo instalar la capa glibc de Termux (glibc)."
    }

    if [ ! -x "$GLIBC_LOADER" ]; then
        show_log_tail
        print_error "No se encontro el cargador glibc (esperado: $GLIBC_LOADER). Reinstala la capa glibc manualmente: pkg reinstall -y glibc"
    fi
}

ensure_glibc_repo() {
    if [ -f "$PREFIX/etc/apt/sources.list.d/glibc.list" ]; then
        return 0
    fi

    run_hidden "Actualizar repositorios" pkg update -y || {
        show_log_tail
        print_error "Falló 'pkg update'. Revisa tu conexión a internet."
    }
    run_hidden "Agregar repositorio glibc" pkg install -y glibc-repo || {
        show_log_tail
        print_error "No se pudo agregar el repositorio glibc de Termux."
    }
    run_hidden "Actualizar repositorios" pkg update -y || {
        show_log_tail
        print_error "Falló 'pkg update'. Revisa tu conexión a internet."
    }
}

fetch_binary_from_url() {
    local url="$1"
    local archive="$TMP_DIR/opencode-linux-arm64.tar.gz"

    curl -fsSL --proto =https --retry 2 --connect-timeout 20 --max-time 900 -o "$archive" "$url" || return 1
    mkdir -p "$TMP_DIR/bin"
    tar -xzf "$archive" -C "$TMP_DIR/bin"
    [ -f "$TMP_DIR/bin/opencode" ]
}

fetch_binary_from_npm() {
    local meta tarball archive

    meta=$(curl -fsSL --proto =https --connect-timeout 20 --max-time 60 "https://registry.npmjs.org/opencode-linux-arm64/latest") || return 1
    tarball=$(printf '%s' "$meta" | grep -o '"tarball":"[^"]*"' | cut -d'"' -f4) || return 1
    [ -n "$tarball" ] || return 1

    archive="$TMP_DIR/opencode-linux-arm64.tgz"
    curl -fsSL --proto =https --retry 2 --connect-timeout 20 --max-time 900 -o "$archive" "$tarball" || return 1
    mkdir -p "$TMP_DIR/npmbin"
    tar -xzf "$archive" -C "$TMP_DIR/npmbin"
    [ -f "$TMP_DIR/npmbin/package/bin/opencode" ]
}

install_launcher() {
    local launcher_src="$SCRIPT_DIR/launcher.c"

    if [ ! -f "$launcher_src" ]; then
        print_error "No se encontró 'launcher.c' junto a install.sh ($SCRIPT_DIR)."
    fi

    if run_hidden "Compilar launcher nativo" cc -O2 -DPREFIX="\"$PREFIX\"" -o "$OPCODE_BIN_DIR/opencode" "$launcher_src"; then
        chmod 755 "$OPCODE_BIN_DIR/opencode"
        INSTALL_LAUNCHER="c"
        return 0
    fi

    show_log_tail
    check_item "Launcher nativo" "skip" "compilador no disponible, usando wrapper"
    write_shell_launcher "$OPCODE_BIN_DIR/opencode"
}

write_shell_launcher() {
    local out="$1"
    cat > "$out" <<EOF
#!${PREFIX}/bin/bash
# OpenCode — Termux launcher (shell wrapper)
# Equivalente a launcher.c: invoca el cargador glibc de la capa glibc.
export SSL_CERT_FILE="${PREFIX}/etc/tls/cert.pem"
exec "${GLIBC_LOADER}" --library-path "${GLIBC_RUNTIME}:${GLIBC_LIB}" "${OPCODE_REAL}" "\$@"
EOF
    chmod 755 "$out"
    INSTALL_LAUNCHER="shell"
}

fetch_opencode_binary() {
    mkdir -p "$OPCODE_SHARE_DIR"

    if download_binary_source "vendor" fetch_binary_from_url "$VENDOR_DL"; then
        INSTALL_METHOD="vendor"
        return 0
    fi

    if download_binary_source "espejo" fetch_binary_from_url "$MIRROR_DL"; then
        INSTALL_METHOD="espejo"
        return 0
    fi

    if download_binary_source "npm" fetch_binary_from_npm; then
        INSTALL_METHOD="npm"
        return 0
    fi

    ensure_termuxvoid_fallback
}

download_binary_source() {
    local label="$1"
    local src="$TMP_DIR/bin/opencode"
    shift

    if [ "$label" = "npm" ]; then
        src="$TMP_DIR/npmbin/package/bin/opencode"
    fi

    if ! run_hidden "Descargar binario ($label)" "$@"; then
        return 1
    fi

    cp "$src" "$OPCODE_REAL"
    chmod 755 "$OPCODE_REAL"

    if ! is_valid_glibc_binary "$OPCODE_REAL"; then
        echo "--- [validacion $label] binario no valido ---" >> "$LOG_FILE"
        rm -f "$OPCODE_REAL"
        check_item "Validar binario ($label)" "skip" "no es un ELF ARM64 valido"
        return 1
    fi

    check_item "Validar binario ($label)" "ok" ""
    return 0
}

is_elf_file() {
    local m
    m=$(head -c4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$m" = "7f454c46" ]
}

build_glibc_runtime() {
    rm -rf "$GLIBC_RUNTIME"
    mkdir -p "$GLIBC_RUNTIME"

    local f name cand

    # Symlink de todas las librerias versionadas reales y de los .so planos que ya son ELF
    for f in "$GLIBC_LIB"/*.so "$GLIBC_LIB"/*.so.*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
            *.so|*.so.*)
                [ -e "$GLIBC_RUNTIME/$name" ] && continue
                ln -sf "$f" "$GLIBC_RUNTIME/$name" 2>/dev/null || true
                ;;
        esac
    done

    # Reasignar librerias cuyo .so plano es un script de enlazado ASCII (libc.so, libm.so, ...)
    # a su version ELF real (.so.6, .so.2, ...) para que el cargador glibc no aborte
    for f in "$GLIBC_LIB"/*.so; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        if is_elf_file "$GLIBC_RUNTIME/$name"; then
            continue
        fi
        for cand in "$GLIBC_LIB/$name".*; do
            [ -f "$cand" ] || continue
            if is_elf_file "$cand"; then
                ln -sf "$cand" "$GLIBC_RUNTIME/$name" 2>/dev/null
                break
            fi
        done
    done

    check_item "Preparar libs glibc" "ok" "$GLIBC_RUNTIME"
}

is_valid_glibc_binary() {
    local bin="$1"

    [ -f "$bin" ] || return 1
    [ "$(uname -m)" = "aarch64" ] || return 1

    local magic
    magic=$(dd if="$bin" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "$magic" = "7f454c46" ] || return 1

    return 0
}

ensure_termuxvoid_fallback() {
    if [ ! -f "$PREFIX/etc/apt/sources.list.d/termuxvoid.list" ]; then
        run_hidden "Actualizar repositorios" pkg update -y || {
            show_log_tail
            print_error "Falló 'pkg update'. Revisa tu conexión a internet."
        }
        run_hidden "Agregar repositorio termuxvoid" add_termuxvoid_repo || {
            show_log_tail
            print_error "No se pudo configurar el repositorio termuxvoid."
        }
        run_hidden "Actualizar repositorios" pkg update -y || {
            show_log_tail
            print_error "Falló 'pkg update'. Revisa tu conexión a internet."
        }
    fi

    if run_hidden "Instalar opencode (termuxvoid)" pkg install -y opencode; then
        INSTALL_METHOD="termuxvoid"
    else
        show_log_tail
        explain_termux_failure
        print_error "Fallaron todas las fuentes de opencode. Revisa el log: $LOG_FILE"
    fi
}

install_opencode() {
    section_header "Instalacion"

    if dpkg -s opencode >/dev/null 2>&1; then
        run_hidden "Quitar paquete opencode previo" pkg uninstall -y opencode || true
    fi

    ensure_glibc_layer
    fetch_opencode_binary
    build_glibc_runtime

    if [ "$INSTALL_METHOD" != "termuxvoid" ]; then
        install_launcher
    fi
}

verify_installation() {
    section_header "Verificacion"

    if [ ! -x "$OPCODE_REAL" ]; then
        print_error "El binario de opencode no esta instalado o no es ejecutable: $OPCODE_REAL"
    fi

    if [ "$INSTALL_METHOD" = "termuxvoid" ]; then
        if command -v opencode &>/dev/null && [ -x "$(command -v opencode)" ]; then
            check_item "Verificar instalacion" "ok" "$(command -v opencode)"
            return 0
        fi
        print_error "La verificacion de opencode fallo. Revisa el paquete termuxvoid."
    fi

    if [ ! -x "$OPCODE_BIN_DIR/opencode" ]; then
        print_error "El launcher no esta instalado o no es ejecutable: $OPCODE_BIN_DIR/opencode"
    fi

    if [ ! -x "$GLIBC_LOADER" ]; then
        print_error "Falta el cargador glibc ($GLIBC_LOADER). Reinstala la capa glibc: pkg reinstall -y glibc"
    fi

    if [ ! -d "$GLIBC_RUNTIME" ]; then
        build_glibc_runtime
    fi

    local out rc
    out=$("$OPCODE_BIN_DIR/opencode" --version 2>&1)
    rc=$?

    # Reintento con un shim recién construido (cubría libs planas .so rotas)
    if [ "$rc" -ne 0 ]; then
        build_glibc_runtime
        out=$("$OPCODE_BIN_DIR/opencode" --version 2>&1)
        rc=$?
    fi

    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
        check_item "Verificar instalacion" "ok" "${out}"
        return 0
    fi

    {
        echo "--- [verificacion] fallo ---"
        echo "exit: $rc"
        echo "output: $out"
        echo "loader src: $GLIBC_LOADER"
        echo "binario: $(readelf -h "$OPCODE_REAL" 2>/dev/null | grep -m1 Class || echo 'no-readelf')"
    } >> "$LOG_FILE"

    echo ""
    echo -e "  ${RED}${BOLD}La verificacion de opencode fallo.${RESET}"
    echo -e "  ${DIM}Exit code:${RESET} ${BOLD}$rc${RESET}"
    if [ -n "$out" ]; then
        echo -e "  ${DIM}Salida:${RESET}"
        printf '    %s\n' "$out" | while IFS= read -r line; do
            echo -e "  ${DIM}  ${line}${RESET}"
        done
    fi
    echo ""
    show_log_tail
    print_error "Revisa la salida de arriba. Si el mensaje es de tagged pointers, reinstala la capa glibc: pkg reinstall -y glibc"
}

# ── Resumen final ────────────────────────────────────────────────────────────

print_summary() {
    local line
    printf -v line "%*s" "$COLS" ""
    line="${line// /─}"

    echo ""
    box_line "├$(make_line)┤"
    box_text "" ""
    box_text "  Instalacion completada exitosamente" "${WHITE}${BOLD}"
    box_text "" ""
    box_line "└$(make_line)┘"
    echo ""

    echo -e "  ${BOLD}Comandos disponibles${RESET}"
    echo ""
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode" "Iniciar OpenCode (TUI interactiva)"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode --version" "Version instalada"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode --help" "Ayuda y comandos"
    if [ "$INSTALL_METHOD" = "termuxvoid" ]; then
        printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "pkg upgrade opencode" "Actualizar opencode"
    else
        printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "bash install.sh" "Actualizar opencode"
    fi
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode auth login" "Autenticar con un proveedor"
    echo ""

    echo -e "  ${BOLD}Archivos instalados${RESET}"
    echo ""
    if [ "$INSTALL_METHOD" = "termuxvoid" ]; then
        printf "    ${DIM}%-30s ${RESET}%s\n" "Origen:" "paquete Termux 'opencode' (termuxvoid)"
    else
        printf "    ${DIM}%-30s ${RESET}%s\n" "Origen:" "binario oficial glibc ($INSTALL_METHOD)"
    fi
    if [ "$INSTALL_LAUNCHER" = "c" ]; then
        printf "    ${DIM}%-30s ${RESET}%s\n" "Launcher:" "$OPCODE_BIN_DIR/opencode (C nativo)"
    elif [ "$INSTALL_LAUNCHER" = "shell" ]; then
        printf "    ${DIM}%-30s ${RESET}%s\n" "Launcher:" "$OPCODE_BIN_DIR/opencode (script wrapper)"
    fi
    printf "    ${DIM}%-30s ${RESET}%s\n" "Binario:" "$OPCODE_REAL"
    printf "    ${DIM}%-30s ${RESET}%s\n" "Configuracion:" "$OPCODE_CONFIG_DIR/"
    if [ -d "$BACKUP_DIR" ] && [ -n "$(find "$BACKUP_DIR" -maxdepth 1 -type d -name 'opencode.backup.*' -print -quit 2>/dev/null || true)" ]; then
        printf "    ${DIM}%-30s ${RESET}%s\n" "Respaldo:" "$BACKUP_DIR/"
    fi
    echo ""

    echo -e "  ${BOLD}Proximos pasos${RESET}"
    echo ""
    echo -e "  ${DIM}1.${RESET} ${BOLD}Configurar un proveedor de IA${RESET}"
    echo -e "     ${DIM}Ejecuta:${RESET}  opencode auth login"
    echo -e "     ${DIM}Sigue las instrucciones para autenticar con tu proveedor favorito${RESET}"
    echo ""

    echo -e "  ${DIM}2.${RESET} ${BOLD}Probar opencode${RESET}"
    echo -e "     ${DIM}Ejecuta:${RESET}  opencode"
    echo ""

    local sep
    printf -v sep "%*s" "$COLS" ""
    sep="${sep// /─}"
    echo -e "  ${DIM}${sep}${RESET}"
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""
}

# ── Desinstalacion ──────────────────────────────────────────────────────────

do_uninstall() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "Desinstalar OpenCode" "$WHITE${BOLD}"
    box_line "└$(make_line)┘"
    echo ""

    if ! ask_yes_no "¿Esta seguro de desinstalar opencode?" "N"; then
        echo -e "  ${DIM}Desinstalacion cancelada.${RESET}"
        exit 0
    fi
    echo ""

    local removed=false

    if command -v opencode &>/dev/null; then
        if dpkg -s opencode >/dev/null 2>&1; then
            echo -e "  ${GREEN}✔${RESET} Desinstalando paquete opencode (termuxvoid)..."
            pkg uninstall -y opencode &>/dev/null || true
            removed=true
        fi
        if [ -f "$OPCODE_BIN_DIR/opencode" ]; then
            echo -e "  ${GREEN}✔${RESET} Eliminando launcher: $OPCODE_BIN_DIR/opencode"
            rm -f "$OPCODE_BIN_DIR/opencode"
            removed=true
        fi
        if [ -d "$OPCODE_SHARE_DIR" ]; then
            echo -e "  ${GREEN}✔${RESET} Eliminando binario: $OPCODE_SHARE_DIR/"
            rm -rf "$OPCODE_SHARE_DIR"
            removed=true
        fi
        if [ -d "$PREFIX/lib/node_modules/opencode-ai" ]; then
            echo -e "  ${GREEN}✔${RESET} Limpiando instalacion npm previa..."
            npm uninstall -g opencode-ai &>/dev/null || true
            removed=true
        fi
        if [ "$removed" = "false" ]; then
            echo -e "  ${YELLOW}−${RESET} No se encontro instalacion de opencode."
        fi
    else
        echo -e "  ${YELLOW}−${RESET} No se encontro instalacion de opencode."
    fi

    if [ -d "$OPCODE_CONFIG_DIR" ]; then
        echo ""
        if ask_yes_no "¿Eliminar tambien la configuracion de opencode?" "N"; then
            rm -rf "$OPCODE_CONFIG_DIR"
            echo -e "  ${GREEN}✔${RESET} Eliminado: $OPCODE_CONFIG_DIR"
        fi
    fi

    echo ""
    echo -e "  ${BOLD}Para eliminar respaldos:${RESET}"
    echo -e "  ${DIM}  rm -rf ${BACKUP_DIR}${RESET}"
    echo ""

    local sep
    printf -v sep "%*s" "$COLS" ""
    sep="${sep// /─}"
    echo -e "  ${DIM}${sep}${RESET}"
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""

    exit 0
}

# ── Ayuda ───────────────────────────────────────────────────────────────────

show_help() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "OpenCode - Termux" "$WHITE${BOLD}"
    box_text "Script de instalacion v${SCRIPT_VERSION}" ""
    box_line "└$(make_line)┘"
    echo ""
    echo -e "  ${BOLD}Uso:${RESET}"
    echo ""
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh" "Instalacion completa"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --help" "Muestra esta ayuda"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --version" "Muestra la version"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --diagnose" "Diagnostica una instalacion (sin cambiar nada)"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --uninstall" "Desinstala opencode"
    echo ""
    echo -e "  ${BOLD}Descripcion:${RESET}"
    echo -e "  ${DIM}Instala OpenCode de forma nativa en Termux."
    echo -e "  ${DIM}Descarga el binario oficial glibc y lo lanza con un"
    echo -e "  ${DIM}launcher nativo Android via la capa glibc de Termux."
    echo -e "  ${DIM}  - Fuentes: vendor oficial, espejo propio, termuxvoid"
    echo -e "  ${DIM}  - Nativo en Termux (sin proot, sin VMs)"
    echo -e "  ${DIM}  - Sin dependencias npm"
    echo -e "  ${DIM}  - Actualizar: re-ejecutar install.sh${RESET}"
    echo ""
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""
    exit 0
}

# ── Diagnostico ─────────────────────────────────────────────────────────────

print_lib_check() {
    local name="$1"
    local file="$2"
    if [ -L "$file" ]; then
        printf "  %-22s %s -> %s\n" "$name" "$(basename "$file")" "$(readlink "$file")"
    elif [ -f "$file" ]; then
        local kind
        if is_elf_file "$file"; then
            kind="ELF valido"
        else
            kind="NO es ELF (script o corrupto)"
        fi
        printf "  %-22s %s  [%s]\n" "$name" "$(basename "$file")" "$kind"
    else
        printf "  %-22s %s  [NO EXISTE]\n" "$name" "$file"
    fi
}

do_diagnose() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "Diagnostico de instalacion" "$WHITE${BOLD}"
    box_line "└$(make_line)┘"
    echo ""

    echo -e "  ${BOLD}Entorno${RESET}"
    printf "  %-22s %s\n" "Arquitectura:" "$(uname -m)"
    printf "  %-22s %s\n" "Termux:" "${TERMUX_VERSION:-no detectado}"
    printf "  %-22s %s\n" "PREFIX:" "$PREFIX"
    echo ""

    echo -e "  ${BOLD}Launcher${RESET}"
    if [ -f "$OPCODE_BIN_DIR/opencode" ]; then
        if head -c2 "$OPCODE_BIN_DIR/opencode" | od -An -tx1 | tr -d ' \n' | grep -q 7f45; then
            echo "  $OPCODE_BIN_DIR/opencode  [binario C nativo]"
        else
            echo "  $OPCODE_BIN_DIR/opencode  [script wrapper]"
            echo "  Contenido:"
            sed -n '1,8p' "$OPCODE_BIN_DIR/opencode" | sed 's/^/    /'
        fi
    else
        echo "  $OPCODE_BIN_DIR/opencode  [NO EXISTE]"
    fi
    echo ""

    echo -e "  ${BOLD}Binario real (opencode.real)${RESET}"
    if [ -f "$OPCODE_REAL" ]; then
        printf "  %-24s %s\n" "Tamanio:" "$(du -h "$OPCODE_REAL" | cut -f1)"
        echo "  Dependencias (DT_NEEDED):"
        readelf -d "$OPCODE_REAL" 2>/dev/null | grep NEEDED | sed 's/0x[0-9a-f]* (NEEDED)  *Shared library/         NEEDED/' || {
            echo "    (readelf no disponible o binario no ELF)"
            echo "    Magic: $(head -c4 "$OPCODE_REAL" | od -An -tx1 | tr -d ' \n')"
        }
    else
        echo "  $OPCODE_REAL  [NO EXISTE]"
    fi
    echo ""

    echo -e "  ${BOLD}Capa glibc${RESET}"
    print_lib_check "cargador" "$GLIBC_LOADER"
    print_lib_check "libc.so" "$GLIBC_LIB/libc.so"
    print_lib_check "libc.so.6" "$GLIBC_LIB/libc.so.6"
    print_lib_check "libm.so.6" "$GLIBC_LIB/libm.so.6"
    print_lib_check "libpthread.so.0" "$GLIBC_LIB/libpthread.so.0"
    print_lib_check "libdl.so.2" "$GLIBC_LIB/libdl.so.2"
    if [ ! -d "$GLIBC_RUNTIME" ]; then
        build_glibc_runtime
    fi
    print_lib_check "shim libc.so" "$GLIBC_RUNTIME/libc.so"
    echo ""

    echo -e "  ${BOLD}Resolucion del cargador (con shim)${RESET}"
    if [ -f "$OPCODE_REAL" ] && [ -x "$GLIBC_LOADER" ]; then
        "$GLIBC_LOADER" --library-path "$GLIBC_RUNTIME:$GLIBC_LIB" --list "$OPCODE_REAL" 2>&1 | while IFS= read -r line; do
            echo -e "  ${DIM}${line}${RESET}"
        done
    else
        echo "  (faltan opencode.real o cargador)"
    fi
    echo ""

    echo -e "  ${BOLD}Prueba directa (via cargador)${RESET}"
    if [ -f "$OPCODE_REAL" ] && [ -x "$GLIBC_LOADER" ]; then
        "$GLIBC_LOADER" --library-path "$GLIBC_RUNTIME:$GLIBC_LIB" "$OPCODE_REAL" --version 2>&1
        echo "  exit=$?"
    fi
    echo ""
    exit 0
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --version|-v)
            echo "opencode-termux v${SCRIPT_VERSION}"
            exit 0
            ;;
        --uninstall)
            do_uninstall
            ;;
        --diagnose)
            do_diagnose
            ;;
        "")
            ;;
        *)
            echo -e "  ${RED}[ERR]${RESET} Opcion desconocida: ${1}"
            echo "  Usa: bash install.sh --help"
            exit 1
            ;;
    esac

    print_banner

    if ! ask_yes_no "¿Deseas continuar con la instalacion?" "S"; then
        echo -e "  ${DIM}Instalacion cancelada.${RESET}"
        exit 0
    fi

    check_environment
    check_dependencies

    local current_version
    current_version=$(detect_installed_version)
    if [ -n "$current_version" ] && ! check_existing "$current_version"; then
        exit 0
    fi

    backup_existing

    INSTALL_FAILED=true
    install_opencode
    verify_installation
    INSTALL_FAILED=false

    print_summary
}

main "$@"
