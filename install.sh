#!/data/data/com.termux/files/usr/bin/bash
#
# OpenCode — Termux
# Script de instalacion para Termux
# v1.0.0
#
# Script creado por Sebastian Laguna
# https://github.com/sebastianl1/opencode-termux
#
# Descripcion:
#   Instala OpenCode de forma nativa en Termux
#   utilizando npm (Node.js). Sin proot, sin VMs, sin Cloud Shell.
#
# Uso:
#   bash install.sh              Instalacion completa
#   bash install.sh --help       Muestra esta ayuda
#   bash install.sh --version    Muestra la version
#   bash install.sh --uninstall  Desinstala opencode
#

set -eEuo pipefail

# ── Configuracion ────────────────────────────────────────────────────────────

SCRIPT_VERSION="1.0.0"
SCRIPT_AUTHOR="Sebastian Laguna"
SCRIPT_REPO="https://github.com/sebastianl1/opencode-termux"

OPCODE_BIN_DIR="$PREFIX/bin"
OPCODE_CONFIG_DIR="$HOME/.config/opencode"
OPCODE_CONFIG_FILE="$OPCODE_CONFIG_DIR/opencode.json"
BACKUP_DIR="$HOME/backups/opencode"
TMP_DIR="$PREFIX/tmp/opencode-install"
LOG_FILE="$TMP_DIR/install.log"
INSTALL_FAILED=false

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

    wait "$pid"
    local exit_code=$?

    printf "\r"

    if [ "$exit_code" -eq 0 ]; then
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET} ${GREEN}hecho${RESET}\n" "$desc"
    else
        printf "  ${RED}✘${RESET} ${BOLD}%-34s${RESET} ${RED}fallo${RESET}\n" "$desc"
        echo ""
        echo -e "  ${DIM}Ultimas lineas del log:${RESET}"
        tail -5 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${DIM}  ${line}${RESET}"
        done
        exit 1
    fi
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
    local node_ok=true
    local npm_ok=true

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
        check_item "Node.js" "ok" "$node_ver"
    else
        check_item "Node.js" "skip" "instalando..."
        node_ok=false
    fi

    if command -v npm &>/dev/null; then
        local npm_ver
        npm_ver=$(npm --version 2>/dev/null)
        check_item "npm" "ok" "v$npm_ver"
    else
        check_item "npm" "skip" "instalando..."
        npm_ok=false
    fi

    echo ""

    if [ "$env_ok" != "true" ] || [ "$arch_ok" != "true" ]; then
        print_error "Este instalador solo funciona en Termux ARM64 (aarch64)."
    fi

    if [ "$node_ok" != "true" ] || [ "$npm_ok" != "true" ]; then
        if ask_yes_no "¿Instalar Node.js y npm?" "S"; then
            run_hidden "Actualizar repositorios" pkg update -y
            run_hidden "Instalar Node.js" pkg install -y nodejs
        else
            print_error "Node.js es necesario para ejecutar OpenCode. Instalalo con: pkg install nodejs"
        fi
    fi
}

check_dependencies() {
    if ! command -v curl &>/dev/null; then
        run_hidden "Actualizar repositorios" pkg update -y
        run_hidden "Instalar curl" pkg install -y curl
    fi
}

check_existing() {
    local current_version="$1"

    section_header "Estado actual"

    check_item "OpenCode" "ok" "$current_version"
    check_item "Origen" "ok" "$OPCODE_CONFIG_DIR"

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

install_opencode() {
    section_header "Instalacion"

    run_hidden "Instalar opencode" npm install -g opencode-ai
}

verify_installation() {
    local version
    if version=$(opencode --version 2>/dev/null); then
        check_item "Verificar instalacion" "ok" "${version}"
    else
        print_error "La verificacion de opencode fallo. Revisa la instalacion."
    fi
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
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode upgrade" "Actualizar opencode"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "opencode auth login" "Autenticar con un proveedor"
    echo ""

    echo -e "  ${BOLD}Archivos instalados${RESET}"
    echo ""
    printf "    ${DIM}%-30s ${RESET}%s\n" "Paquete npm:" "opencode-ai"
    printf "    ${DIM}%-30s ${RESET}%s\n" "Binario:" "$(command -v opencode 2>/dev/null || echo "$OPCODE_BIN_DIR/opencode")"
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
        echo -e "  ${GREEN}✔${RESET} Desinstalando paquete npm..."
        npm uninstall -g opencode-ai &>/dev/null || true
        removed=true
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
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --uninstall" "Desinstala opencode"
    echo ""
    echo -e "  ${BOLD}Descripcion:${RESET}"
    echo -e "  ${DIM}Instala OpenCode de forma nativa en Termux."
    echo -e "  ${DIM}Utiliza npm para instalar el paquete opencode-ai."
    echo -e "  ${DIM}  - Nativo en Termux (sin proot, sin VMs)"
    echo -e "  ${DIM}  - Node.js como unica dependencia"
    echo -e "  ${DIM}  - Actualizable via opencode upgrade${RESET}"
    echo ""
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
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
