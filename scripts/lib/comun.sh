#!/bin/bash

# Scrie un mesaj pe ecran si in fisierul de jurnal, cu data, ora si nivelul de
# importanta. Informatiile sensibile (hash-uri de parola) nu se transmit acestei
# functii, pentru a nu ajunge in jurnal.
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

# Afiseaza o eroare si opreste aplicatia cu cod de iesire diferit de zero.
opreste() {
    eroare "$@"
    exit 1
}

# Executa o comanda pe sistemul indicat de primul argument: direct, daca este
# "local", sau prin ssh, daca este "remote".
# Datorita acestei functii, restul codului nu depinde de modul de rulare: el
# cere executia "pe sursa" sau "pe destinatie", iar variabilele SURSA si
# DESTINATIE stabilesc, la pornire, care dintre ele este masina locala.
ruleaza() {
    local unde="$1"
    shift

    if [ "$unde" = "local" ]; then
        "$@"
    else
        ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "$@"
    fi
}

# Varianta cu drepturi de root a functiei de mai sus, pentru operatiile care
# citesc sau modifica fisiere de sistem.
ruleaza_sudo() {
    local unde="$1"
    shift

    if [ "$unde" = "local" ]; then
        sudo "$@"
    else
        ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "sudo $*"
    fi
}

# Verifica daca masina remote este accesibila prin ssh, inainte de orice alta
# operatie. Optiunea BatchMode impiedica ssh sa ceara o parola interactiv:
# daca autentificarea pe baza de chei nu functioneaza, comanda esueaza imediat,
# in loc sa blocheze aplicatia in asteptarea unei parole.
verifica_conexiunea() {
    info "Verific conexiunea SSH catre ${USER_SSH}@${TINTA}"

    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${USER_SSH}@${TINTA}" "true" 2>/dev/null; then
        opreste "Nu ma pot conecta la ${USER_SSH}@${TINTA}. Verifica adresa, serverul SSH si cheile."
    fi

    local nume
    nume=$(ssh -o BatchMode=yes "${USER_SSH}@${TINTA}" "hostname")
    info "Conexiune stabilita cu: $nume"
}

# Verifica daca un utilitar necesar (de exemplu rsync) exista pe sistemul
# indicat, pentru a raporta lipsa lui explicit, nu printr-o eroare ulterioara.
verifica_comanda() {
    local unde="$1"
    local comanda="$2"

    if ! ruleaza "$unde" command -v "$comanda" >/dev/null 2>&1; then
        opreste "Comanda '$comanda' nu este disponibila pe sistemul $unde."
    fi
}

# Cere confirmarea utilizatorului. Returneaza succes numai la raspuns afirmativ;
# orice alt raspuns este tratat ca refuz.
confirma() {
    local intrebare="$1"
    local raspuns

    read -r -p "$intrebare [d/n] " raspuns

    case "$raspuns" in
        d|D|da|DA|Da) return 0 ;;
        *)            return 1 ;;
    esac
}
