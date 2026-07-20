#!/bin/bash

set -uo pipefail

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR_SCRIPT/lib/comun.sh"
source "$DIR_SCRIPT/lib/colectare.sh"
source "$DIR_SCRIPT/lib/comparare.sh"
source "$DIR_SCRIPT/lib/aplicare.sh"

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
    --mod        Rolul masinii pe care rulezi acum: sursa | destinatie
    --tinta      Adresa IP a celeilalte masini
    --user       Utilizatorul folosit pentru conexiunea SSH
    --config     Fisier de configurare (parametrii au prioritate)
    --categorii  Ce se cloneaza: pachete,utilizatori,home,cron
    --help       Afiseaza acest mesaj

EXEMPLE
    ./clonare.sh --mod sursa --tinta 192.168.56.102 --user vladescu
    ./clonare.sh --config ../config/clonare.conf

OBSERVATII
    Aplicatia afiseaza diferentele si cere o singura confirmare inainte de a
    modifica ceva. La refuz, niciun sistem nu este modificat. Destinatia devine
    identica cu sursa la categoriile clonate.
EOF
}

parseaza_parametri() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --mod)        [ $# -ge 2 ] || opreste "--mod necesita o valoare."; MOD="$2"; shift 2 ;;
            --tinta)      [ $# -ge 2 ] || opreste "--tinta necesita o valoare."; TINTA="$2"; shift 2 ;;
            --user)       [ $# -ge 2 ] || opreste "--user necesita o valoare."; USER_SSH="$2"; shift 2 ;;
            --config)     [ $# -ge 2 ] || opreste "--config necesita o valoare."; CONFIG="$2"; shift 2 ;;
            --categorii)  [ $# -ge 2 ] || opreste "--categorii necesita o valoare."; CATEGORII="$2"; shift 2 ;;
            --help|-h)    ajutor; exit 0 ;;
            *) eroare "Optiune necunoscuta: $1"; echo "Foloseste --help." >&2; exit 1 ;;
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
    [ -n "$MOD" ]      || opreste "--mod este obligatoriu. Vezi --help."
    [ -n "$TINTA" ]    || opreste "--tinta este obligatoriu. Vezi --help."
    [ -n "$USER_SSH" ] || opreste "--user este obligatoriu. Vezi --help."
    if [ "$MOD" != "sursa" ] && [ "$MOD" != "destinatie" ]; then
        opreste "Valoare invalida pentru --mod: '$MOD'. Valori acceptate: sursa | destinatie"
    fi
    if ! echo "$TINTA" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
        opreste "Adresa invalida pentru --tinta: '$TINTA'. Format asteptat: x.x.x.x"
    fi
}

stabileste_rolurile() {
    if [ "$MOD" = "sursa" ]; then
        SURSA="local"; DESTINATIE="remote"
    else
        SURSA="remote"; DESTINATIE="local"
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

    # --- COLECTARE (CF-05..CF-08) ---
    if categorie_activa pachete; then
        colecteaza_pachete "$SURSA" > /tmp/pachete_sursa.txt
        colecteaza_pachete "$DESTINATIE" > /tmp/pachete_dest.txt
    fi
    if categorie_activa utilizatori; then
        colecteaza_utilizatori "$SURSA" > /tmp/useri_sursa.txt
        colecteaza_utilizatori "$DESTINATIE" > /tmp/useri_dest.txt
        colecteaza_grupuri "$SURSA" > /tmp/grupuri_sursa.txt
        colecteaza_grupuri "$DESTINATIE" > /tmp/grupuri_dest.txt
    fi

    # --- AFISAREA DIFERENTELOR (CF-09, CF-10) ---
    info "Calculez diferentele..."
    if categorie_activa pachete; then
        afiseaza_diferente "PACHETE" /tmp/pachete_sursa.txt /tmp/pachete_dest.txt
    fi
    if categorie_activa utilizatori; then
        afiseaza_diferente "GRUPURI" /tmp/grupuri_sursa.txt /tmp/grupuri_dest.txt
        afiseaza_diferente "UTILIZATORI" /tmp/useri_sursa.txt /tmp/useri_dest.txt
    fi

    # --- INTEROGAREA (CF-11) ---
    echo
    if ! confirma "Aplic clonarea? Destinatia va deveni identica cu sursa."; then
        info "Clonare anulata de utilizator. Niciun sistem nu a fost modificat."
        exit 0
    fi

    # --- APLICAREA (CF-12..CF-21) ---
    # Ordinea corecta: intai stergem (useri, apoi grupuri), ca sa eliberam
    # UID/GID-urile, apoi cream (grupuri, apoi useri), ca noii useri sa
    # primeasca exact UID/GID-urile de pe sursa.
    if categorie_activa utilizatori; then
        info "--- Sterg utilizatorii in plus ---"
        sterge_utilizatori /tmp/useri_sursa.txt /tmp/useri_dest.txt
        info "--- Sterg grupurile in plus ---"
        sterge_grupuri /tmp/grupuri_sursa.txt /tmp/grupuri_dest.txt
        info "--- Creez grupurile lipsa ---"
        creaza_grupuri /tmp/grupuri_sursa.txt /tmp/grupuri_dest.txt
        info "--- Creez utilizatorii lipsa (passwd + shadow in bloc) ---"
        creaza_utilizatori /tmp/useri_sursa.txt /tmp/useri_dest.txt
    fi

    if categorie_activa home; then
        info "--- Transfer home-directory-urile ---"
        while IFS= read -r user; do
            [ -z "$user" ] && continue
            aplica_home "$user"
        done < <(diff_lipsa /tmp/useri_sursa.txt /tmp/useri_dest.txt)
    fi

    if categorie_activa pachete; then
        info "--- Aplic pachetele ---"
        aplica_pachete /tmp/pachete_sursa.txt /tmp/pachete_dest.txt
    fi

    if categorie_activa cron; then
        info "--- Recreez cronjob-urile ---"
        while IFS= read -r user; do
            [ -z "$user" ] && continue
            aplica_cronjoburi "$user"
        done < /tmp/useri_sursa.txt
    fi

    info "=== Clonare finalizata ==="
}

main "$@"
