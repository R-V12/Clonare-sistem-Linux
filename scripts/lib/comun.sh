#!/bin/bash

log() {
    local nivel="$1"
    shift
    local mesaj="$*"
    local moment
    moment=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$moment] $nivel  $mesaj"
    if [ -n "${JURNAL:-}" ]; then
        echo "[$moment] $nivel  $mesaj" >> "$JURNAL"
    fi
}

info()    { log "INFO   " "$@"; }
atentie() { log "WARNING" "$@"; }
eroare()  { log "ERROR  " "$@" >&2; }

opreste() {
    eroare "$@"
    exit 1
}

ruleaza() {
    local unde="$1"
    shift
    if [ "$unde" = "local" ]; then
        "$@"
    else
        ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "$@"
    fi
}

ruleaza_sudo() {
    local unde="$1"
    shift
    if [ "$unde" = "local" ]; then
        sudo "$@"
    else
        ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "sudo $*"
    fi
}

verifica_conexiunea() {
    info "Verific conexiunea SSH catre ${USER_SSH}@${TINTA}"
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${USER_SSH}@${TINTA}" "true" 2>/dev/null; then
        opreste "Nu ma pot conecta la ${USER_SSH}@${TINTA}. Verifica adresa, serverul SSH si cheile."
    fi
    local nume
    nume=$(ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "hostname")
    info "Conexiune stabilita cu: $nume"
}

verifica_comanda() {
    local unde="$1"
    local comanda="$2"
    if ! ruleaza "$unde" command -v "$comanda" >/dev/null 2>&1; then
        opreste "Comanda '$comanda' nu este disponibila pe sistemul $unde."
    fi
}

confirma() {
    local intrebare="$1"
    local raspuns
    read -r -p "$intrebare [d/n] " raspuns
    case "$raspuns" in
        d|D|da|DA|Da) return 0 ;;
        *)            return 1 ;;
    esac
}
