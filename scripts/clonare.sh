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

# Afiseaza mesajul de ajutor cu parametrii disponibili si exemple de utilizare.
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

# Citeste parametrii din linia de comanda si ii pune in variabilele globale.
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

# Incarca optiunile dintr-un fisier de configurare.
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

# Verifica parametrii inainte de orice conexiune sau modificare.
valideaza() {
    [ -n "$MOD" ]      || opreste "Parametrul --mod este obligatoriu. Vezi --help."
    [ -n "$TINTA" ]    || opreste "Parametrul --tinta este obligatoriu. Vezi --help."
    [ -n "$USER_SSH" ] || opreste "Parametrul --user este obligatoriu. Vezi --help."

    if [ "$MOD" != "sursa" ] && [ "$MOD" != "destinatie" ]; then
        opreste "Valoare invalida pentru --mod: '$MOD'. Valori acceptate: sursa | destinatie"
    fi

    if ! echo "$TINTA" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
        opreste "Adresa invalida pentru --tinta: '$TINTA'. Se asteapta o adresa IPv4 de forma x.x.x.x, exemplu: 192.168.56.102"
    fi

    local octet
    for octet in ${TINTA//./ }; do
        if [ "$octet" -gt 255 ]; then
            opreste "Adresa invalida pentru --tinta: '$TINTA'. Fiecare numar trebuie sa fie intre 0 si 255."
        fi
    done
}

# Stabileste care sistem este local si care remote, in functie de modul de rulare.
# Dupa acest pas, restul codului foloseste doar $SURSA si $DESTINATIE.
stabileste_rolurile() {
    if [ "$MOD" = "sursa" ]; then
        SURSA="local"; DESTINATIE="remote"
    else
        SURSA="remote"; DESTINATIE="local"
    fi
    info "Mod: $MOD  (sursa=$SURSA, destinatie=$DESTINATIE)"
}

# Verifica daca o categorie a fost selectata pentru clonare.
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

    # Colectarea starii de pe ambele sisteme
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

    # Calculul si afisarea diferentelor
    info "Calculez diferentele..."
    if categorie_activa pachete; then
        afiseaza_diferente "PACHETE" /tmp/pachete_sursa.txt /tmp/pachete_dest.txt
    fi
    if categorie_activa utilizatori; then
        afiseaza_diferente "GRUPURI" /tmp/grupuri_sursa.txt /tmp/grupuri_dest.txt
        afiseaza_diferente "UTILIZATORI" /tmp/useri_sursa.txt /tmp/useri_dest.txt
    fi

    # Confirmarea utilizatorului, inainte de orice modificare
    echo
    if ! confirma "Aplic clonarea? Destinatia va deveni identica cu sursa."; then
        info "Clonare anulata de utilizator. Niciun sistem nu a fost modificat."
        exit 0
    fi

    # Ordinea de aplicare: intai se sterg utilizatorii si grupurile in plus,
    # eliberand UID-urile si GID-urile, apoi se creeaza cele de pe sursa,
    # care primesc astfel exact aceiasi identificatori.
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

    # Home-directory-urile se transfera dupa crearea utilizatorilor, ca
    # proprietarul fisierelor sa poata fi aplicat corect.
    # Lista se incarca intr-un tablou, pentru ca ssh consuma intrarea standard
    # si ar intrerupe o bucla care citeste direct de la ea.
    if categorie_activa home; then
        info "--- Transfer home-directory-urile ---"
        local user
        mapfile -t useri_noi < <(diff_lipsa /tmp/useri_sursa.txt /tmp/useri_dest.txt)
        for user in "${useri_noi[@]}"; do
            [ -z "$user" ] && continue
            aplica_home "$user"
        done
    fi

    if categorie_activa pachete; then
        info "--- Aplic pachetele ---"
        aplica_pachete /tmp/pachete_sursa.txt /tmp/pachete_dest.txt
    fi

    # Cronjob-urile se recreeaza la final, dupa ce utilizatorii exista.
    if categorie_activa cron; then
        info "--- Recreez cronjob-urile ---"
        local u
        mapfile -t toti_userii < /tmp/useri_sursa.txt
        for u in "${toti_userii[@]}"; do
            [ -z "$u" ] && continue
            aplica_cronjoburi "$u"
        done
    fi

    info "=== Clonare finalizata ==="
}

main "$@"
