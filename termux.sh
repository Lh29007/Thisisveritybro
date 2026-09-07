#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
# Termux-Proton
# Proton/Wine-style CLI adapted for Termux
# ============================================================

set -u

VERSION="0.1.0"
NAME="termux-proton"

BASE="$HOME/.termux-proton"
RUNTIMES="$BASE/runtimes"
PREFIXES="$BASE/prefixes"
GAMES="$BASE/games"
CACHE="$BASE/cache"
LOGS="$BASE/logs"
CONFIG="$BASE/config"

DEFAULT_PREFIX="$PREFIXES/default"

mkdir -p \
    "$RUNTIMES" \
    "$PREFIXES" \
    "$GAMES" \
    "$CACHE" \
    "$LOGS" \
    "$CONFIG"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

success() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# ------------------------------------------------------------
# Architecture
# ------------------------------------------------------------

detect_arch() {
    case "$(uname -m)" in
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv8l|armv8*)
            ARCH="arm32"
            ;;
        armv7l|armv7*)
            ARCH="arm32"
            ;;
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        i686|i386)
            ARCH="x86"
            ;;
        *)
            ARCH="unknown"
            ;;
    esac
}

# ------------------------------------------------------------
# Dependency checking
# ------------------------------------------------------------

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_termux() {
    if [ -z "${PREFIX:-}" ]; then
        warn "PREFIX n'est pas défini."
        warn "Ce script est prévu pour Termux."
    fi
}

check_dependencies() {
    local missing=()

    for cmd in bash curl tar unzip; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        warn "Dépendances manquantes : ${missing[*]}"
        echo
        echo "Installe-les avec :"
        echo
        echo "  pkg install ${missing[*]}"
        echo
    fi
}

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

new_log() {
    echo "$LOGS/run-$(timestamp).log"
}

# ------------------------------------------------------------
# Information
# ------------------------------------------------------------

show_info() {
    detect_arch

    echo
    echo -e "${BOLD}${CYAN}$NAME${RESET} v$VERSION"
    echo
    echo "Architecture : $ARCH"
    echo "Termux PREFIX : ${PREFIX:-unknown}"
    echo "Base          : $BASE"
    echo "Runtimes      : $RUNTIMES"
    echo "Prefixes      : $PREFIXES"
    echo "Games         : $GAMES"
    echo "Logs          : $LOGS"
    echo
}

# ------------------------------------------------------------
# Initialisation
# ------------------------------------------------------------

cmd_init() {
    info "Initialisation de Termux-Proton..."

    mkdir -p \
        "$RUNTIMES" \
        "$PREFIXES" \
        "$GAMES" \
        "$CACHE" \
        "$LOGS" \
        "$CONFIG"

    detect_arch

    cat > "$CONFIG/settings.conf" <<EOF
# Termux-Proton configuration

ARCH=$ARCH

DEFAULT_RUNTIME=wine
DEFAULT_PREFIX=$DEFAULT_PREFIX

BOX64_ENABLED=auto
BOX86_ENABLED=auto

TERMUX_X11=auto
EOF

    success "Termux-Proton initialisé."
    echo
    echo "Répertoire : $BASE"
}

# ------------------------------------------------------------
# Prefix management
# ------------------------------------------------------------

prefix_create() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        die "Usage: $NAME prefix create <nom>"
    fi

    local prefix="$PREFIXES/$name"

    if [ -d "$prefix" ]; then
        warn "Le préfixe '$name' existe déjà."
        return 0
    fi

    mkdir -p "$prefix"

    success "Préfixe créé : $name"
    echo
    echo "WINEPREFIX=$prefix"
}

prefix_delete() {
    local name="${1:-}"

    [ -z "$name" ] && die "Usage: $NAME prefix delete <nom>"

    local prefix="$PREFIXES/$name"

    if [ ! -d "$prefix" ]; then
        die "Préfixe introuvable : $name"
    fi

    read -r -p "Supprimer le préfixe '$name' ? [y/N] " answer

    case "$answer" in
        y|Y|yes|YES)
            rm -rf "$prefix"
            success "Préfixe supprimé."
            ;;
        *)
            info "Annulé."
            ;;
    esac
}

prefix_list() {
    echo
    echo -e "${BOLD}Préfixes disponibles${RESET}"
    echo

    local found=0

    for prefix in "$PREFIXES"/*; do
        if [ -d "$prefix" ]; then
            echo "  - $(basename "$prefix")"
            found=1
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  Aucun préfixe."
    fi

    echo
}

# ------------------------------------------------------------
# Runtime management
# ------------------------------------------------------------

runtime_list() {
    echo
    echo -e "${BOLD}Runtimes${RESET}"
    echo

    local found=0

    for runtime in "$RUNTIMES"/*; do
        if [ -d "$runtime" ]; then
            echo "  - $(basename "$runtime")"
            found=1
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  Aucun runtime installé."
    fi

    echo
}

runtime_find_wine() {
    local runtime="${1:-wine}"

    local candidates=(
        "$RUNTIMES/$runtime/bin/wine"
        "$RUNTIMES/$runtime/bin/wine64"
        "$PREFIX/bin/wine"
        "$PREFIX/bin/wine64"
        "$PREFIX/bin/wine-stable"
    )

    for wine in "${candidates[@]}"; do
        if [ -x "$wine" ]; then
            echo "$wine"
            return 0
        fi
    done

    return 1
}

runtime_install_termux() {
    info "Installation de Wine via les paquets Termux..."

    if ! command_exists pkg; then
        die "pkg n'est pas disponible. Termux requis."
    fi

    pkg update

    if pkg install wine -y; then
        success "Wine installé."
    else
        error "Impossible d'installer Wine depuis les dépôts Termux."
        echo
        echo "Selon ton architecture et ton dépôt Termux,"
        echo "Wine peut ne pas être disponible nativement."
        return 1
    fi
}

runtime_install() {
    local runtime="${1:-wine}"

    case "$runtime" in
        wine)
            runtime_install_termux
            ;;

        *)
            die "Runtime inconnu : $runtime"
            ;;
    esac
}

# ------------------------------------------------------------
# Box64 / Box86 detection
# ------------------------------------------------------------

find_box64() {
    local candidates=(
        "$PREFIX/bin/box64"
        "$RUNTIMES/box64/box64"
        "$HOME/bin/box64"
    )

    for bin in "${candidates[@]}"; do
        if [ -x "$bin" ]; then
            echo "$bin"
            return 0
        fi
    done

    if command_exists box64; then
        command -v box64
        return 0
    fi

    return 1
}

find_box86() {
    local candidates=(
        "$PREFIX/bin/box86"
        "$RUNTIMES/box86/box86"
        "$HOME/bin/box86"
    )

    for bin in "${candidates[@]}"; do
        if [ -x "$bin" ]; then
            echo "$bin"
            return 0
        fi
    done

    if command_exists box86; then
        command -v box86
        return 0
    fi

    return 1
}

# ------------------------------------------------------------
# Prefix environment
# ------------------------------------------------------------

prepare_prefix() {
    local prefix="$1"

    mkdir -p "$prefix"

    export WINEPREFIX="$prefix"

    # Useful Wine defaults
    export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}"

    # Termux filesystem compatibility
    export TMPDIR="${TMPDIR:-$PREFIX/tmp}"

    mkdir -p "$TMPDIR"
}

# ------------------------------------------------------------
# Executable architecture detection
# ------------------------------------------------------------

detect_exe_arch() {
    local file="$1"

    if ! command_exists file; then
        echo "unknown"
        return
    fi

    local output
    output="$(file "$file" 2>/dev/null || true)"

    case "$output" in
        *"PE32+ executable"*)
            echo "x86_64"
            ;;
        *"PE32 executable"*)
            echo "x86"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------

run_wine() {
    local exe="$1"
    shift

    local runtime="${TP_RUNTIME:-wine}"
    local prefix="${TP_PREFIX:-$DEFAULT_PREFIX}"

    local wine

    if ! wine="$(runtime_find_wine "$runtime")"; then
        error "Wine n'est pas installé."
        echo
        echo "Essaie :"
        echo "  $NAME runtime install wine"
        return 1
    fi

    prepare_prefix "$prefix"

    detect_arch

    local exe_arch
    exe_arch="$(detect_exe_arch "$exe")"

    info "Architecture Android : $ARCH"
    info "Architecture EXE     : $exe_arch"
    info "Préfixe               : $prefix"
    info "Wine                  : $wine"

    local log
    log="$(new_log)"

    echo
    info "Lancement..."
    echo "Log : $log"
    echo

    {
        echo "========================================"
        echo "Termux-Proton"
        echo "Date: $(date)"
        echo "EXE: $exe"
        echo "Architecture: $ARCH"
        echo "EXE architecture: $exe_arch"
        echo "Prefix: $prefix"
        echo "Wine: $wine"
        echo "========================================"
        echo

        # ARM -> x86/x64
        if [ "$ARCH" = "arm64" ]; then

            if [ "$exe_arch" = "x86_64" ]; then
                local box64

                if box64="$(find_box64)"; then
                    info "Box64 détecté : $box64"
                    "$box64" "$wine" "$exe" "$@"
                else
                    error "EXE x86_64 détecté mais Box64 n'est pas installé."
                    echo
                    echo "Installe/configure Box64 avant de lancer ce programme."
                    return 1
                fi

            elif [ "$exe_arch" = "x86" ]; then
                local box86

                if box86="$(find_box86)"; then
                    info "Box86 détecté : $box86"
                    "$box86" "$wine" "$exe" "$@"
                elif box64="$(find_box64)"; then
                    info "Box64 détecté : $box64"
                    "$box64" "$wine" "$exe" "$@"
                else
                    error "EXE x86 détecté mais aucun émulateur x86 n'est disponible."
                    return 1
                fi

            else
                "$wine" "$exe" "$@"
            fi

        else
            "$wine" "$exe" "$@"
        fi

    } 2>&1 | tee "$log"

    local status=${PIPESTATUS[0]}

    echo

    if [ "$status" -eq 0 ]; then
        success "Programme terminé."
    else
        error "Programme terminé avec le code : $status"
        echo "Log : $log"
    fi

    return "$status"
}

cmd_run() {
    local prefix="$DEFAULT_PREFIX"
    local runtime="wine"

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --prefix)
                [ $# -ge 2 ] || die "--prefix nécessite un nom"
                prefix="$PREFIXES/$2"
                shift 2
                ;;

            --runtime)
                [ $# -ge 2 ] || die "--runtime nécessite un nom"
                runtime="$2"
                shift 2
                ;;

            --)
                shift
                break
                ;;

            -*)
                die "Option inconnue : $1"
                ;;

            *)
                break
                ;;
        esac
    done

    [ $# -ge 1 ] || die "Usage: $NAME run [--prefix nom] programme.exe [arguments...]"

    local exe="$1"
    shift

    [ -f "$exe" ] || die "Fichier introuvable : $exe"

    export TP_PREFIX="$prefix"
    export TP_RUNTIME="$runtime"

    run_wine "$exe" "$@"
}

# ------------------------------------------------------------
# Install helper
# ------------------------------------------------------------

cmd_install() {
    info "Installation de l'environnement Termux-Proton..."

    check_termux

    if command_exists pkg; then
        pkg update

        pkg install \
            bash \
            curl \
            wget \
            tar \
            unzip \
            file \
            proot \
            coreutils \
            findutils \
            -y || true
    fi

    cmd_init

    echo
    success "Installation terminée."
    echo
    echo "Prochaine étape :"
    echo
    echo "  $NAME runtime install wine"
}

# ------------------------------------------------------------
# Logs
# ------------------------------------------------------------

show_logs() {
    echo
    echo -e "${BOLD}Logs${RESET}"
    echo

    ls -1t "$LOGS" 2>/dev/null | head -20

    echo
}

show_last_log() {
    local last

    last="$(ls -1t "$LOGS"/*.log 2>/dev/null | head -1 || true)"

    if [ -z "$last" ]; then
        warn "Aucun log."
        return
    fi

    less "$last" 2>/dev/null || cat "$last"
}

# ------------------------------------------------------------
# Game management
# ------------------------------------------------------------

game_list() {
    echo
    echo -e "${BOLD}Jeux / programmes${RESET}"
    echo

    local found=0

    for game in "$GAMES"/*; do
        if [ -d "$game" ]; then
            echo "  - $(basename "$game")"
            found=1
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  Aucun jeu."
    fi

    echo
}

game_create() {
    local name="${1:-}"

    [ -n "$name" ] || die "Usage: $NAME game create <nom>"

    mkdir -p "$GAMES/$name"

    success "Répertoire créé : $GAMES/$name"
}

# ------------------------------------------------------------
# Doctor
# ------------------------------------------------------------

cmd_doctor() {
    detect_arch

    echo
    echo -e "${BOLD}${CYAN}Termux-Proton Doctor${RESET}"
    echo

    echo "Architecture : $ARCH"

    if command_exists wine; then
        success "Wine détecté : $(command -v wine)"
    else
        warn "Wine non détecté."
    fi

    if box64="$(find_box64)"; then
        success "Box64 détecté : $box64"
    else
        warn "Box64 non détecté."
    fi

    if box86="$(find_box86)"; then
        success "Box86 détecté : $box86"
    else
        warn "Box86 non détecté."
    fi

    if command_exists termux-x11; then
        success "Termux:X11 détecté."
    else
        warn "Termux:X11 non détecté."
    fi

    if [ -n "${DISPLAY:-}" ]; then
        success "DISPLAY=$DISPLAY"
    else
        warn "DISPLAY n'est pas défini."
    fi

    echo
    echo "Dossiers :"

    for dir in "$BASE" "$RUNTIMES" "$PREFIXES" "$GAMES" "$LOGS"; do
        if [ -d "$dir" ]; then
            success "$dir"
        else
            warn "$dir"
        fi
    done

    echo
}

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

show_help() {
    cat <<EOF

${BOLD}${CYAN}Termux-Proton${RESET} v$VERSION

Un gestionnaire type Proton/Wine pour Termux.

${BOLD}COMMANDES${RESET}

  install
      Installe les dépendances et initialise Termux-Proton.

  init
      Initialise les répertoires.

  info
      Affiche les informations système.

  doctor
      Vérifie l'environnement.

  runtime install wine
      Installe Wine depuis Termux.

  runtime list
      Liste les runtimes.

  prefix create <nom>
      Crée un préfixe Wine.

  prefix delete <nom>
      Supprime un préfixe.

  prefix list
      Liste les préfixes.

  run <programme.exe>
      Lance un programme Windows.

  run --prefix <nom> <programme.exe>
      Lance avec un préfixe précis.

  run --runtime <nom> <programme.exe>
      Lance avec un runtime précis.

  game create <nom>
      Crée un répertoire de jeu.

  game list
      Liste les jeux.

  logs
      Liste les logs.

  logs last
      Affiche le dernier log.

${BOLD}EXEMPLES${RESET}

  $NAME install

  $NAME doctor

  $NAME runtime install wine

  $NAME prefix create test

  $NAME run --prefix test programme.exe

  $NAME game create monjeu

${BOLD}RÉPERTOIRES${RESET}

  $BASE
  ├── runtimes/
  ├── prefixes/
  ├── games/
  ├── cache/
  ├── logs/
  └── config/

EOF
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    detect_arch

    local command="${1:-help}"
    shift || true

    case "$command" in

        install)
            cmd_install
            ;;

        init)
            cmd_init
            ;;

        info)
            show_info
            ;;

        doctor)
            cmd_doctor
            ;;

        runtime)
            local sub="${1:-list}"
            shift || true

            case "$sub" in
                install)
                    runtime_install "${1:-wine}"
                    ;;
                list)
                    runtime_list
                    ;;
                *)
                    die "Usage: $NAME runtime {install|list}"
                    ;;
            esac
            ;;

        prefix)
            local sub="${1:-list}"
            shift || true

            case "$sub" in
                create)
                    prefix_create "${1:-}"
                    ;;
                delete)
                    prefix_delete "${1:-}"
                    ;;
                list)
                    prefix_list
                    ;;
                *)
                    die "Usage: $NAME prefix {create|delete|list}"
                    ;;
            esac
            ;;

        run)
            cmd_run "$@"
            ;;

        game)
            local sub="${1:-list}"
            shift || true

            case "$sub" in
                create)
                    game_create "${1:-}"
                    ;;
                list)
                    game_list
                    ;;
                *)
                    die "Usage: $NAME game {create|list}"
                    ;;
            esac
            ;;

        logs)
            if [ "${1:-}" = "last" ]; then
                show_last_log
            else
                show_logs
            fi
            ;;

        version|-v|--version)
            echo "$NAME $VERSION"
            ;;

        help|-h|--help)
            show_help
            ;;

        *)
            error "Commande inconnue : $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"
