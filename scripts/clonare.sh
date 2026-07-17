#!/bin/bash

set -euo pipefail

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR_SCRIPT/lib/comun.sh"
source "$DIR_SCRIPT/lib/colectare.sh"

MOD=""
TINTA=""
USER_SSH=""
CONFIG=""
CATEGORII="pachete,utilizatori,home,cron"
JURNAL="$DIR_SCRIPT/../logs/clonare.log"

ajutor() {
    cat << 'EOF'
clonare.sh - aduce sistemul destinatie in aceeasi stare ca sistemul sursa

UTILIZARE
    ./clonare.sh --mod <sursa|destinatie> --tinta <ip> --user <utilizator>
    ./clonare.sh --config <fisier>

PARAMETRI
    --mod        Rolul masinii pe care rulezi acum:
                   sursa      - masina aceasta este referinta
                   destinatie - masina aceasta va fi modificata
    --tinta      Adresa IP a celeilalte masini
    --user       Utilizatorul folosit pentru conexiunea SSH
    --config     Fisier de configurare (parametrii din linia de comanda
                 au prioritate fata de valorile din fisier)
    --categorii  Ce se colecteaza si compara, separat prin virgula
                 Implicit: pachete,utilizatori,home,cron
    --help       Afiseaza acest mesaj

EXEMPLE
    ./clonare.sh --mod sursa --tinta 192.168.56.102 --user vladescu
    ./clonare.sh --config ../config/clonare.conf
    ./clonare.sh --mod sursa --tinta 192.168.56.102 --user vladescu --categorii pachete

OBSERVATII
    Aplicatia afiseaza diferentele si cere o singura confirmare inainte de a
    modifica ceva. La refuz, niciun sistem nu este modificat.
EOF
}

parseaza_parametri() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --mod)
                [ $# -ge 2 ] || opreste "Parametrul --mod necesita o valoare."
                MOD="$2"; shift 2 ;;
            --tinta)
                [ $# -ge 2 ] || opreste "Parametrul --tinta necesita o valoare."
                TINTA="$2"; shift 2 ;;
            --user)
                [ $# -ge 2 ] || opreste "Parametrul --user necesita o valoare."
                USER_SSH="$2"; shift 2 ;;
            --config)
                [ $# -ge 2 ] || opreste "Parametrul --config necesita o valoare."
                CONFIG="$2"; shift 2 ;;
            --categorii)
                [ $# -ge 2 ] || opreste "Parametrul --categorii necesita o valoare."
                CATEGORII="$2"; shift 2 ;;
            --help|-h)
                ajutor; exit 0 ;;
            *)
                eroare "Optiune necunoscuta: $1"
                echo "Foloseste --help pentru lista parametrilor." >&2
                exit 1 ;;
        esac
    done
}

citeste_config() {
    local fisier="$1"

    [ -f "$fisier" ] || opreste "Fisierul de configurare nu exista: $fisier"
    [ -r "$fisier" ] || opreste "Fisierul de configurare nu poate fi citit: $fisier"

    source "$fisier"

    [ -n "${CONF_MOD:-}" ]       && MOD="$CONF_MOD"
    [ -n "${CONF_TINTA:-}" ]     && TINTA="$CONF_TINTA"
    [ -n "${CONF_USER:-}" ]      && USER_SSH="$CONF_USER"
    [ -n "${CONF_CATEGORII:-}" ] && CATEGORII="$CONF_CATEGORII"
    [ -n "${CONF_JURNAL:-}" ]    && JURNAL="$CONF_JURNAL"

    return 0
}

valideaza() {
    [ -n "$MOD" ]      || opreste "Parametrul --mod este obligatoriu. Vezi --help."
    [ -n "$TINTA" ]    || opreste "Parametrul --tinta este obligatoriu. Vezi --help."
    [ -n "$USER_SSH" ] || opreste "Parametrul --user este obligatoriu. Vezi --help."

    if [ "$MOD" != "sursa" ] && [ "$MOD" != "destinatie" ]; then
        opreste "Valoare invalida pentru --mod: '$MOD'. Valori acceptate: sursa | destinatie"
    fi

    if ! echo "$TINTA" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
        opreste "Adresa invalida pentru --tinta: '$TINTA'. Format asteptat: x.x.x.x"
    fi
}

stabileste_rolurile() {
    if [ "$MOD" = "sursa" ]; then
        SURSA="local"
        DESTINATIE="remote"
    else
        SURSA="remote"
        DESTINATIE="local"
    fi
    info "Mod: $MOD  (sursa=$SURSA, destinatie=$DESTINATIE)"
}

categorie_activa() {
    echo "$CATEGORII" | tr ',' '\n' | grep -qx "$1"
}

main() {
    parseaza_parametri "$@"

    if [ -n "$CONFIG" ]; then
        citeste_config "$CONFIG"
        parseaza_parametri "$@"
    fi

    valideaza

    mkdir -p "$(dirname "$JURNAL")"
    info "=== Clonare pornita ==="

    stabileste_rolurile

    verifica_conexiunea
    verifica_comanda "$SURSA" rsync
    verifica_comanda "$DESTINATIE" rsync

    if categorie_activa pachete; then
        info "Colectez pachetele de pe sursa"
        colecteaza_pachete "$SURSA" > /tmp/pachete_sursa.txt
        info "Colectez pachetele de pe destinatie"
        colecteaza_pachete "$DESTINATIE" > /tmp/pachete_dest.txt
        info "Pachete: $(wc -l < /tmp/pachete_sursa.txt) pe sursa, $(wc -l < /tmp/pachete_dest.txt) pe destinatie"
    fi

    if categorie_activa utilizatori; then
        info "Colectez utilizatorii de pe sursa"
        colecteaza_utilizatori "$SURSA" > /tmp/useri_sursa.txt
        info "Colectez utilizatorii de pe destinatie"
        colecteaza_utilizatori "$DESTINATIE" > /tmp/useri_dest.txt
        info "Utilizatori: $(wc -l < /tmp/useri_sursa.txt) pe sursa, $(wc -l < /tmp/useri_dest.txt) pe destinatie"
    fi

    info "Colectare finalizata."
}

main "$@"
